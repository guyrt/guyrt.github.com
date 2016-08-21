library(ggplot2)
library(scales)
library(readr)
library(dplyr)
library(tidyr)
library(tibble)

dfraw <- as_tibble(jsonlite::fromJSON("C:/tmp/pac_data.json"))
dfraw <- dfraw %>% select(DONOR_COMMITTEE_FEC_ID, DONOR_CANDIDATE_FEC_ID, FILER_COMMITTEE_ID_NUMBER, NumContributions=`count(CONTRIBUTION_AMOUNT_{F3L_Bundled})`, TotalContributions=`sum(CONTRIBUTION_AMOUNT_{F3L_Bundled})`)


# Load candidates from json.
candidates <- as_tibble(jsonlite::fromJSON("C:/tmp/candidate.json"))
candidates <- candidates %>% filter(CAND_PCC != "")  # the rest have to be small!

committees <- as_tibble(jsonlite::fromJSON("C:/tmp/committee.json"))
committees <- committees %>% select(CMTE_NM, CMTE_ID)

df_with_candidate <- dfraw %>% left_join(candidates, by=c("FILER_COMMITTEE_ID_NUMBER" = "CAND_PCC"))
df_with_candidate <- df_with_candidate %>% select(-CAND_ELECTION_YR, -CAND_ST1, -CAND_ST2, -CAND_ZIP)

df_with_committee <- df_with_candidate %>% left_join(committees, by=c("DONOR_COMMITTEE_FEC_ID" = "CMTE_ID"))

# Affiliations show can remove the rest.
df_total_by_party <- df_with_committee %>% 
  filter(CAND_OFFICE == "H") %>%
  group_by(CAND_PTY_AFFILIATION, CAND_OFFICE) %>% 
  summarise(TotalContributions=sum(TotalContributions), NumContributions=sum(NumContributions)) %>% 
  arrange(desc(NumContributions))  %>%
  select(-CAND_OFFICE)

ggplot(df_total_by_party, aes(x=reorder(CAND_PTY_AFFILIATION, -NumContributions), y=NumContributions)) + 
  geom_bar(stat="identity") +
  ggtitle("Number of Contributions from PACs to each Party's House Races") + 
  xlab("Party")


df <- df_with_committee %>% 
  filter((CAND_PTY_AFFILIATION == "DEM") | (CAND_PTY_AFFILIATION == "REP"))

byPartyAndStatus <- df %>% 
  group_by(CAND_PTY_AFFILIATION, CAND_OFFICE, DONOR_COMMITTEE_FEC_ID, CMTE_NM) %>% 
  summarise(TotalContributions=sum(TotalContributions), NumContributions=sum(NumContributions))

byPartyAndStatus %>% arrange(desc(TotalContributions))

# Produce a pivot table
byPartyAndStatusNarrow <- byPartyAndStatus %>% 
  tidyr::unite(Donor, DONOR_COMMITTEE_FEC_ID, CMTE_NM, sep = "__") %>%
  select(-NumContributions)

byPartyAndStatusWide <- byPartyAndStatusNarrow %>% 
  tidyr::spread(key = CAND_PTY_AFFILIATION, value=TotalContributions, fill = 0) %>% 
  separate(Donor, into=c("FEC_ID", "CMTE_NM"), sep = "__") %>% 
  mutate(TotalContributions=DEM + REP) %>%
  mutate(DemShare=DEM / TotalContributions) %>%
  arrange(desc(TotalContributions)) %>%
  filter(FEC_ID != "")

#
# House only.
#
houseRacesOnly <- byPartyAndStatusWide %>% filter(CAND_OFFICE == "H") %>% 
  filter(FEC_ID != 'NA') %>%
  mutate(CumulativeContributions=cumsum(TotalContributions)) %>%
  mutate(Index=row_number(desc(TotalContributions))) %>% 
  select(-CAND_OFFICE)
  
houseRacesOnly <- houseRacesOnly %>%
  mutate(CumulativeContributions=CumulativeContributions / max(houseRacesOnly$CumulativeContributions))

houseRacesOnly$Committee <- c(
  head(houseRacesOnly$CMTE_NM, 6), 
  replicate(nrow(houseRacesOnly) - 6, "Other")
)

#
# President
#
presidentRacesOnly <- byPartyAndStatusWide %>% filter(CAND_OFFICE == "P") %>% filter(FEC_ID != 'NA') %>%
  mutate(CumulativeContributions=cumsum(TotalContributions)) %>%
  mutate(Index=row_number(desc(TotalContributions)))

presidentRacesOnly <- presidentRacesOnly %>%
  mutate(CumulativeContributions=CumulativeContributions / max(houseRacesOnly$CumulativeContributions))

#
# Senate
#
senateRacesOnly <- byPartyAndStatusWide %>% filter(CAND_OFFICE == "S") %>% filter(FEC_ID != 'NA') %>%
  mutate(CumulativeContributions=cumsum(TotalContributions)) %>%
  mutate(Index=row_number(desc(TotalContributions)))

senateRacesOnly <- senateRacesOnly %>%
  mutate(CumulativeContributions=CumulativeContributions / max(houseRacesOnly$CumulativeContributions))



# histogram

cbPalette <- c("blue", "red", "#E69F00", "#56B4E9", "#aaaaaa", "#0072B2", "red")
plt <- ggplot(houseRacesOnly, aes(x=DemShare, weights=TotalContributions, fill=Committee)) + 
  geom_histogram(aes(y=..count..), bins = 30, alpha=.66) + 
  scale_fill_manual(values=cbPalette, guide=guide_legend(ncol = 2)) +
  geom_vline(aes(xintercept=0.43)) +
  theme(legend.position="bottom") + 
  theme(legend.text = element_text(size=6)) +
  annotate("text", x = .55, y = 6000000, label = "Current Makeup of House") +
  ylab("Amount of Money") +
  scale_y_continuous(labels = comma) + theme(axis.text.y=element_text(angle=45)) +
  xlab("Percent of PAC's money going to Democrats") + 
  ggtitle("PAC money in House Races by Partisanship of the PAC")

show(plt)

houseRacesOnly <- houseRacesOnly %>% 
  mutate(rowNumber=row_number()) %>%
  mutate(RowDecile=as.factor(ntile(rowNumber, 10)))

plt <- ggplot(houseRacesOnly, aes(x=DemShare, weight=TotalContributions, fill=RowDecile)) + 
  geom_histogram(aes(y=..ndensity..), bins = 20, alpha=.66) + 
  geom_vline(aes(xintercept=0.43)) +
  theme(legend.position="bottom") + 
  ylab("Amount of Money") +
  scale_y_continuous(labels = comma) + theme(axis.text.y=element_text(angle=45)) +
  xlab("Percent of PAC's money going to Democrats") + 
  ggtitle("PAC money in House Races by Partisanship of the PAC") + 

show(plt)


# partisans
houseRacesOnly <- houseRacesOnly %>% 
  mutate(IsPartisan=ifelse(DemShare > 0.95, "Dem", ifelse(DemShare < 0.05, "Rep", "None"))) %>% 
  group_by(IsPartisan) %>% summarise(TotalContributions=sum(TotalContributions))

presidentRacesOnly <- presidentRacesOnly %>% mutate(IsPartisan=ifelse(DemShare > 0.95, "Dem", ifelse(DemShare < 0.05, "Rep", "None")))
presidentRacesOnly %>% group_by(IsPartisan) %>% summarise(TotalContributions=sum(TotalContributions))

# Dems
houseRacesDems <- houseRacesOnly %>% filter(IsPartisan == "Dem") %>% select(CMTE_NM, TotalContributions)
houseRacesDems <- houseRacesDems %>% 
  mutate(CumDistributions=cumsum(TotalContributions))

houseRacesDemsForPlot <- houseRacesDems %>% 
  mutate(RollingPercentOfContributions=CumDistributions/max(CumDistributions)) %>%
  mutate(LaggedPercentOfContributions=lag(TotalContributions, default=0)/max(CumDistributions))


houseRacesOther <- houseRacesOnly %>% ungroup %>% 
  filter(IsPartisan == "None") %>% 
  select(FEC_ID, CMTE_NM, Committee, TotalContributions, DemShare) %>%
  mutate(PercentOfContributions=100 * TotalContributions / sum(TotalContributions))

View(houseRacesOther)

houseRacesOther$Committee <- c(
  head(houseRacesOther$CMTE_NM, 10), 
  replicate(nrow(houseRacesOther) - 10, "Other")
)



plt <- ggplot(houseRacesOther, aes(x=DemShare, weights=TotalContributions)) + 
  geom_histogram(aes(y=..count..), bins = 30, alpha=.66) + 
  geom_vline(aes(xintercept=0.43)) +
  theme(legend.position="bottom") + 
  theme(legend.text = element_text(size=6)) +
  annotate("text", x = .55, y = 6000000, label = "Current Makeup of House") +
  ylab("Amount of Money") +
  scale_y_continuous(labels = comma) + theme(axis.text.y=element_text(angle=45)) +
  xlab("Percent of PAC's money going to Democrats") + 
  ggtitle("PAC money in House Races by Partisanship of the PAC")

show(plt)


View(houseRacesDems)
# Reps
houseRacesOnly %>% filter(IsPartisan == "Rep") %>% select(CMTE_NM, TotalContributions)


# cumulative
ggplot(houseRacesOnly, aes(x=Index, y=CumulativeContributions)) + geom_point() + geom_vline(aes(xintercept=751.6)) + geom_hline(aes(yintercept=.8))





# Get Totals
byPartyAndStatusWide %>% group_by(CAND_OFFICE) %>% summarise(sum(DEM), sum(REP))

# Who is the biggest?  ACTBLUE
byPartyAndStatus %>% filter(DONOR_COMMITTEE_FEC_ID == "C00401224")
# For REPs: MAJORITY COMMITTEE PAC--MC PAC
byPartyAndStatus %>% filter(DONOR_COMMITTEE_FEC_ID == "C00428052")







plt <- ggplot(houseRacesOnly, aes(x=DemShare, weights=TotalContributions)) + 
  geom_histogram(aes(y=..count..), bins = 30, alpha=.66) + 
  scale_fill_manual(values=cbPalette, guide=guide_legend(ncol = 2)) +
  geom_vline(aes(xintercept=0.43)) +
  theme(legend.position="bottom") + 
  theme(legend.text = element_text(size=6)) +
  annotate("text", x = .55, y = 6000000, label = "Current Makeup of House") +
  ylab("Amount of Money") +
  scale_y_continuous(labels = comma) + theme(axis.text.y=element_text(angle=45)) +
  xlab("Percent of PAC's money going to Democrats") + 
  ggtitle("PAC money in House Races by Partisanship of the PAC")

show(plt)


# Donations TO ACTBLUE
dfToCommittee <- dfraw %>% 
  inner_join(committees, by=c("FILER_COMMITTEE_ID_NUMBER" = "CMTE_ID")) %>% 
  inner_join(committees, by=c("DONOR_COMMITTEE_FEC_ID" = "CMTE_ID"), suffix=c("_Recipient", "_Donor"))


# C00401224  actblue
# C00545947  ryan
dfToCommittee %>% 
  filter(FILER_COMMITTEE_ID_NUMBER == "C00096156") %>%
  group_by(DONOR_COMMITTEE_FEC_ID, CMTE_NM_Donor) %>%
  summarise(TotalContributions=sum(TotalContributions), NumContributions=sum(NumContributions)) %>%
  arrange(desc(TotalContributions))

# honeywell
# C00096156

honeywell <- dfToCommittee %>% 
  filter(DONOR_COMMITTEE_FEC_ID == "C00096156") %>%
  group_by(FILER_COMMITTEE_ID_NUMBER, CMTE_NM_Recipient) %>%
  summarise(TotalContributions=sum(TotalContributions), NumContributions=sum(NumContributions)) %>%
  arrange(desc(TotalContributions))

View(honeywell)

View(df_with_committee %>% filter(DONOR_COMMITTEE_FEC_ID == "C00096156") %>% arrange(CAND_OFFICE_ST, CAND_OFFICE_DISTRICT))

# lockheed
# C00303024

lockheed <- dfToCommittee %>% 
  filter(DONOR_COMMITTEE_FEC_ID == "C00303024") %>%
  group_by(FILER_COMMITTEE_ID_NUMBER, CMTE_NM_Recipient) %>%
  summarise(TotalContributions=sum(TotalContributions), NumContributions=sum(NumContributions)) %>%
  arrange(desc(TotalContributions))

View(lockheed)

View(df_with_committee %>% filter(DONOR_COMMITTEE_FEC_ID == "C00303024") %>% arrange(CAND_OFFICE_ST, CAND_OFFICE_DISTRICT))

#
# Figure out how much money is given to other pacs.
#

houseRacesPartisan <- houseRacesOnly %>% filter(IsPartisan != "Other")

fromOtherPACToPartisan <- df_with_committee %>% 
  semi_join(houseRacesPartisan, by=c("FILER_COMMITTEE_ID_NUMBER" = "FEC_ID")) %>%
  select(DONOR_COMMITTEE_FEC_ID, FILER_COMMITTEE_ID_NUMBER, NumContributions, TotalContributions) %>%
  semi_join(houseRacesOther, by=c("DONOR_COMMITTEE_FEC_ID" = "FEC_ID"))


fromOtherPACToPartisan %>% summarize(sum(TotalContributions))

fromOtherPACToPartisanAgg <- fromOtherPACToPartisan %>% 
  group_by(DONOR_COMMITTEE_FEC_ID, FILER_COMMITTEE_ID_NUMBER) %>%
  summarize(TotalContributions=sum(TotalContributions))

fromOtherPACToPartisanAgg %>% ungroup %>% summarize(sum(TotalContributions))


# try to get the percent spent on House races.
contributionsByIdOffice <- byPartyAndStatusWide %>% 
  semi_join(houseRacesPartisan, by="FEC_ID") %>%
  group_by(FEC_ID) %>%
  summarize(TotalContributions=sum(TotalContributions))

contributionsByIdOffice %>% ungroup %>% summarize(sum(TotalContributions))

contributionsByIdHouse <- byPartyAndStatusWide %>% 
  filter(CAND_OFFICE == "H") %>%
  semi_join(houseRacesPartisan, by="FEC_ID") %>%
  group_by(FEC_ID) %>%
  summarize(HouseContributions=sum(TotalContributions))

contributionsByIdHouse %>% ungroup %>% summarize(sum(HouseContributions))

  
contributionHouseRatio <- contributionsByIdOffice %>% 
  left_join(contributionsByIdHouse) %>%
  mutate(HouseRatio=HouseContributions / TotalContributions)

contributionHouseRatio %>% ungroup %>% summarize(sum(HouseContributions))

contributionHouseRatio %>% filter(HouseRatio < 1)

contributionHouseRatio <- select(contributionHouseRatio, FEC_ID, HouseRatio)

fromOtherPACToPartisanHouseOnly <- fromOtherPACToPartisanAgg %>% 
  inner_join(contributionHouseRatio, by=c("FILER_COMMITTEE_ID_NUMBER" = "FEC_ID")) %>%
  mutate(HouseContributions=TotalContributions * HouseRatio)

fromOtherPACToPartisanHouseOnly %>% ungroup %>% summarize(sum(HouseContributions))

# Get biggest PAC contributors 
PACToPartisanBySize <- fromOtherPACToPartisanHouseOnly %>% 
  group_by(DONOR_COMMITTEE_FEC_ID) %>% summarize(TotalContributions=sum(HouseContributions)) %>%
  arrange(desc(TotalContributions))
  
PACKey <- houseRacesOther %>% select(FEC_ID, CMTE_NM)

PACToPartisanBySize %>% 
  left_join(PACKey, by=c("DONOR_COMMITTEE_FEC_ID" = "FEC_ID")) %>%
  select(CommitteeName=CMTE_NM, TotalContributions)



