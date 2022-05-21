
Every now and then I come back to the mountain of open data that governments produce. There's probably something useful in there, but I worry that the people who can access that data (me!) and the people with the right questions and domain knowledge may struggle to align. That leaves groups with some vested interest as the only group that can effectively access and use all that public data. 

I'm trying to provide a few templates for quickly getting government data into useable shape, starting with the Federal Election Commission. The FEC publishes every transaction for all candidates for federal public office (some states do similar things for state offices, though the access is less secure - more on that later). These open data pipelines can be found [here](https://github.com/guyrt/opendatapipes/) which will get updates when I get time.

Another goal of this effort is to explore data pipelines more or less from first principles. I won't use (yet) some of the basic tools for a Modern Data Stack. Rather, I'm trying to build on some more primitive capabilities like Azure Queues and Azure Functions (yes, Azure. I work at Microsoft and they give employees some money every month to kick the Azure tires in side projects.) This post will be more about the tech than the data. One of the reasons for building on primitive things is that it forces me to grapple with some details like retries, error handling, ect. that 

### What do I want from my Data Pipeline?

A data pipeline is just a set of steps that need to operate in some order to move data from a source to some useful state and location. In my case, I want to download daily financial filing files from the FEC's bulk data warehouse and process them to a useful format in my own data lake. This should minimally facilitate easy investigation and may one day feed useful projects directly.

There are a few criteria I'm going to consider when I build out and later modify my data pipeline:
1) Cost. Sure! This is my spare time project. Tools that let me "spin the meter" only when useful work is being done are useful.

Everything else here is about maintainability.

2) Extensibility - what is required to add a new step in my pipeline? 

3) Discoverabilty - how much context is required by a new person (likely future me!) to understand the pipeline enough to add a new step or to fix a bug? 

4) Visibility - how easy is it to track performance. Concretely, how will I know if something is failing later?

5) Robustness - can the system respond to changes in the data format or to instability in services? 

6) Testability - in particular here I'm looking for the ability to experiment with new phases in a workflow.

At this stage, I'm not concerned with optimizing performance, meaning optimizing the number of actions I can take in a given time.

### Pipeline V1: Azure Functions are Great

In anticipation of a V2 of this thing (spoiler alert), I made a git tag for the V1 pipeline [here](https://github.com/guyrt/opendatapipes/tree/fec-blog-1). This pipe works! You could use it yourself given the right set of Azure credentials, which I'll discuss in a minute. 

Our first pipeline uses [Azure Functions](https://docs.microsoft.com/en-us/azure/azure-functions/functions-overview) to run each step the pipeline. Azure Functions are like Lambda Functions in AWS and everything here would work there. Functions are *serverless* which just means the server is owned by someone else. 

Each Function contains an action that triggers the function, a piece of code that executes on trigger, and potentially outputs or *side effects* that can either update data or trigger additional Functions. Thus, each step in our pipeline can be written as an Azure Function, and we can string them together by making the side effect of one function the trigger of the next. Here are my functions:

**PopulateFetchQueue** [code](https://github.com/guyrt/opendatapipes/tree/fec-blog-1/fec/src/PopulateFetchQueue) - every day, insert a request into a queue to process files for that day.
- Trigger: timer. This triggers every 12 hours in my case and we trust that some other process will avoid duplicating effort if files are updated only every 24 hours. 
- Side Effects: inserts records into an Azure Queue for each file location we want to pull on a daily basis. Messages in this queue are json dictionaries with keys `path` and `blobpath`.
The trigger and side effect info are stored in a file called [function.json](https://github.com/guyrt/opendatapipes/blob/fec-blog-1/fec/src/PopulateFetchQueue/function.json) that defines my function. Note that the timer schedule and the output queue (`q-urlstofetch`) are defined in here.

**ForcePopulateFetchQueue** [code](https://github.com/guyrt/opendatapipes/tree/fec-blog-1/fec/src/ForcePopulateFetchQueue) - allow me to force execute the PopulateFetchQueue logic for a day. Useful for backfilling and testing.
- Trigger: web. This Function exposes an API I can POST to.
- Side Effects: same as PopulateFetchQueue.

**DownloadZipFromQueue** [code](https://github.com/guyrt/opendatapipes/tree/fec-blog-1/fec/src/DownloadZipFromQueue) - download a single zip file from the FEC website and save it into Azure Blob Storage.
- Trigger: queue. This reads from the `q-urlstofetch` queue. 
- Side Effects: (1) Upload a downloaded zip file to a blob location in the queue trigger (`blobpath` key). (2) Write a message to the `q-filestounzip` queue.

**UnzipFile** [code](https://github.com/guyrt/opendatapipes/tree/fec-blog-1/fec/src/UnzipFile) - unzip a single zip file containing a folder and upload all files (nonrecursively) to Azure Blob Storage.
- Trigger: queue. This reads from the `q-filestounzip` queue.
- Side Effects: (1) Upload unzipped files to a blob location that is based on `blobpath` in the queue trigger. (2) Write a message to the `q-filestodecode` queue for each file in the unzipped folder.

**ProcessFileToKeyValue** [code](https://github.com/guyrt/opendatapipes/tree/fec-blog-1/fec/src/ProcessFileToKeyValue) - finally some business logic! This is by far the most complicated function, and the only one that needs to know about the data formats from my source. This function converts strange delimited files into human readable JSON files and splits each line type into a separate file. I actually use a library I wrote years ago to do the heavy lifting. 
- Trigger: queue. This reads from the `q-filestodecode` queue.
- Side Effects: (1) Upload processed json files to a blob location. (2) Write a message to the `q-jsonfilestomerge` queue. 

*Aside* - it took some searching to figure out how to submit multiple outputs in a queue in one Function execution. Turns out if you write a tuple of strings this turns into multiple messages. 

### Passing Judgment

So how does this do?

1) Cost - Extra cheap! My queue + function executions are well under a dollar per month. I pay a few dollars for an Application Insights instance to collect logs from all functions. I'm probably overpaying the (fixed) cost here but who really cares?

And now for the bad news!

2) Extensibility

There are two types of extensibility. If I want to add a step "linearly" in my pipeline this is relatively straightforward. For instance, I could listen to `q-jsonfilestomerge` and do something. If I wanted to do two actions at any point in my pipeline, then I would need to switch my queue provider from Azure Queues, which allow a single consumer (basically a classic queue) to something like Kafka or Azure Service Bus Queues that allow multiple subscribers.

3) Discoverability

Each step in my pipeline is an independent Azure Function coupled only by read/write relationships to specific queues. This makes it relatively easy to understand each step (they are, e.g. easily unit testable). In practice, writing these functions in spare bits of time including while traveling, I found that the work to "load the entire project" into memory was relatively high. If I wanted to understand the full flow of information, I had to to back to the list above to remember it.

4) Visibility

Azure Storage Queues create a poison queue called `<my-queue>-poison` where messages that were unprocessable go. For instance, there is a queue `q-filestounzip-poison` that will contain the input messages that were unprocessable by UnzipFile. This is pretty handy, but my current design produces a poison queue for every input queue in the project. I have to look at 4 separate queues to know if any particular step is failing.

5) and 6) Robustness and Testability - let's punt on these for now while we make some changes to improve discoverability and visibility.

But first, I want to call out a good idea that will help me iterate. The actual business logic in all cases is contained in a library called [dataloadlib](https://github.com/guyrt/opendatapipes/tree/fec-blog-1/fec/src/dataloadlib). So I can change my pipeline management system without making any changes to the business logic. I could also use the same pipeline system with a different set of business logic. 

### Pipeline V1.5: Switch from lot of functions to single.

