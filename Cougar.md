Run Every Trail in Cougar Mountain State Park
=============================================

(image of park)

Hey here's a terrible idea! Let's run every trail in Cougar all at once!

Cougar Mountain is park near Seattle with "about 40 miles" of hilly trails. 
It's pretty popular with the trail running crowd in Seattle and surrounding towns,
especially for mid-week training runs. This winter I started wondering what it would
take to run it all at once.

The trouble is the park layout itself. The picture below shows a typical intersection wiht three trails. Any trip that covers all Shy Bear and the Deceiver Trail must cover 
either Deceiver twice
or either the east or west leg of Shy Bear twice. So what's the most efficient way to cover the entire park?

Here's a route that covers 74.5 total miles. In the process, computed 55 miles of total trails, so it has 20 miles of repetition.

(put conclusion here with picture of route)

Below, I'll detail how I gathered data and estimated an optimal route.

1: Getting and Cleaning (and Cleaning) Some Data
-------------------------------------------------

All of my code can be found in [this GitHub repo](http://github.com/guyrt/routefinder/)

To start exploring the route algorithmically, I downloaded a bulk export of the park and surrounding areas from OpenStreetMap.
The raw data I pulled can be found in my [repo](https://github.com/guyrt/routefinder/blob/master/data/cougar.osm) or pulled directly from OpenStreetMap.

OpenStreetMap treats the world as Nodes, Ways, and Relations. Nodes are points in space. 
Ways are an ordered list of points in space tha form a shape. Everything from buildings 
to trails to highways to portions of park boundary are ways in OSM. Relations are 
unordered (I think) sets of ways that have some relationship. Long roads are often 
relations. Municipal and park boundaries are often relations. 

Several rounds of cleaning removed unnecessary ways like [buildings](https://github.com/guyrt/routefinder/blob/master/src/RouteFinder/RouteCleaner/Transformers/DropBuildings.cs) and [rivers](https://github.com/guyrt/routefinder/blob/master/src/RouteFinder/RouteCleaner/Transformers/DropWater.cs), [collapsed parking lots to a single point](https://github.com/guyrt/routefinder/blob/master/src/RouteFinder/RouteCleaner/Transformers/CollapseParkingLots.cs), and [split ways that are bisected by other ways](https://github.com/guyrt/routefinder/blob/master/src/RouteFinder/RouteCleaner/Transformers/SplitBisectedWays.cs). 
I also classified trails and roads. The categories are trails in the park that required running, roads in the park I could use as byways, and trails or roads that are outside the park that I could choose to use as "shortcuts" between required running.
Identifying which ways are in the park uses a triangulation method called [Ear Clipping](https://github.com/guyrt/routefinder/blob/master/src/RouteFinder/RouteCleaner/PolygonUtils/PolygonTriangulation.cs) to convert Cougar Mountain Park into dozens of triangles. Once the park is a set of triangles, it's trivial to determine if any node falls into one of the triangles and therefore into the park. The map below shows the results of my triangularization. Clearly some triangles are suboptimal.

TODO - triangles

The results are below. Red trails must be run. Blue roads were in the park but aren't required running. Gray lines are trails or roads that fall outside of the park boundaries.

TODO - containment

2: Route Finding
-----------------

All of my route finding code can be found in [RouteFinder](https://github.com/guyrt/routefinder/tree/master/src/RouteFinder/RouteFinder) in the repo, and [GraphBuilder.cs](https://github.com/guyrt/routefinder/blob/master/src/RouteFinder/RouteFinderCmd/GraphBuilder.cs) is a good starting point.

OpenStreeMap defines a graph of nodes connected by adjacency in a Way, but the graph is 
overly verbose. I collapse the raw graph into a weighted, undirected graph. Vertices in my 
collapsed graph are nodes that are intersection points of more than one way. Edges between 
vertices represent whole ways (technically parts of ways since I split any ways that were 
bisected by another way). This method requires a little cleanup from situations where a 
pair of nodes have two ways that connect them and a few other oddities. 

The theoretical problem I'm solving is the [Route Inspection Problem](https://en.wikipedia.org/wiki/Route_inspection_problem), also known as the Chinese Postman Problem. Formally, the problem is to find the shortest circuit that visits every edge in an undirected, weighted graph. In trail runner terms, find the minimal mileage to run every trail at least once. 

If every node in a graph has even degree, then the problem is trivial. (Degree is the 
number of edges meet at a node.) Starting in the parking lot, follow nodes at random and 
mark them as followed. If you arrive back at the parking lot, there are no unmarked edges 
leaving the parking lot, and there are unvisited edges in the graph, then simply pick a 
node on your path with unmarked edges. There will be at least one such node on a connected 
graph, and it will have at least 2 unmarked edges! Follow random trails until you arrive 
back at that edge. Repeat the process until no more edges are unmarked. A cool property of 
graphs with only even-degree edges is that every path will eventually end up back where it started. I actually [use this fact](https://github.com/guyrt/routefinder/blob/master/src/RouteFinder/RouteFinder/RouteFinder.cs#L115) as a sanity check in my algorithm.

Practically, the solution to the Route Inspection Problem hinges on nodes with odd degree. 
Every odd degree node represents "waste" since a path that enters and leaves the node on 
different trails will always use an even number of edges. At some point, to visit the 
final edge, the path must re-traverse one edge on the vertex. A (not necessarily optimal) 
route inspection path adds copies of some edges to the graph so that every vertex has an 
even degree.


So the total algorithm is:
0) Build a graph from the trail map.
1) Find a set of edges to duplicate so that every node has even degree. (This is the hard part.)
2) Find non-overlapping circuits in that multi-graph.
3) Combine the multigraphs into a route.

The real algorithm (finding optimal duplicate edges)
----------------------------------------------------

I want to convey two facts about the optimal solution to the Route Inspection Problem.

First, an optimal, polynomial time solution exists and is called the Blossom Algorithm. 
A pretty good explanation of it can be found [here](http://pub.ist.ac.at/~vnk/papers/blossom5.pdf).

Second, I found a source in an [Urban Operations Research textbook](http://web.mit.edu/urban_or_book/www/book/chapter6/6.4.4.html) claiming that with maps of urban areas, a near optimal solution to the problem can be found by inspection. They point to two key pieces of information. First, in the optimal solution, no two shortest paths share any nodes. Second, odd nodes tend to match with nearby odd nodes. 

Armed with hubris and this observation from a textbook from the internet, I started thinking about potential heuristics. One such heuristic that I'll describe is based on the idea of greedy regret minimization.

The idea is to find edges to connect such that the cost of not using that connection is
very high. The cost of not connecting two edges is equal to the cost of the next least expensive connection between the two nodes minus the cost of the connection under consideration. So the algorithm ranks all nodes by the amount of regret introduced by not using the minimal connection. Then it takes the node with the most amount of potential regret, adds the optimal edges to make it even, and repeats the process. A heap and a minimum spanning tree with early stopping make this a relatively inexpensive operation.

I'm not sure how much more expensive my algorithm is than the BlossomV optimal because I
haven't written BlossomV yet. But inspection (see below) suggests that it's not bad.

TODO optimal path.

<<<here>>>

A few addendum
---------------

I assumed that the trail network is connected. Practically speaking, this was true except for a tiny trail that crosses a corner of the park in the southwest corner.

Technically, my regret minimization algorithm looks at the difference between the best connection and the average of the next 2 connections. This is because sometimes your greedy algorithm will end up selecting a connection for a node that is farther down the list. I tried various values for the number of connections to average. Just using 2 was suboptimal (76 miles) while larger numbers were all within a few yards of the same.
