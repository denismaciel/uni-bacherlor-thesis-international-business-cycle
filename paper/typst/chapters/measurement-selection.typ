#import "../template.typ": *

= Aspects of the Data
<aspects-of-the-data>
== Selection of Unit of Measurement <measure>
One of the crucial tasks while writing this paper was to choose in which unit of measurement the data would be expressed. The OECD's #emph[National Accounts] offers 27 different measures, 20 of which might be relevant to measure stock values of the variables we are interested in. The other seven refer either to growth or population measurements.

Unfortunately, BKK does not mention expressly which unit they have opted for noting only that they have used real values for all variables except for net exports, which was measured in current prices.

Confronted with the dilemma of which unit of measurement to use, we have followed three steps to make a decision:

+ Data on output was downloaded from OECD's website in all measures available.

+ A loop in R was applied to calculate the cross-country correlations of output between the United States with the ten other BKK countries in #emph[all] measures.

+ We compared the results and chose the one most similar to BKK's.

If the data between 1947:1 and 2015:2 are considered, there are enough observations, such that the cross-correlation of output between the US and other the other sample can be computed in #emph[nine] units of measurement. But if only the BKK's interval (1970:1 - 1990:2) is considered, correlations between the US and all other countries can be computed in only #emph[four] different measures. @tab:measure displays the cross-correlations of the United States resulting from these 4 measures along with the same correlations calculated by BKK and ACZ.

#measure-table() <tab:measure>

We first dismiss CARSA and CPCARSA measures. They not only yield correlations that strongly differ from BKK's figures but also both refer to current prices. This contrasts sharply with BKK's data, which are expressed in real terms.

VOBARSA and VPVOBARSA measures are clearly the closest not only to BKK's but also to ACZ's results. Both yield the same figures, because they represent the same measurement, only scaled by different factors: VOBARSA is expressed in national currency, while VPVOBARSA in US dollars. Multiplying a time series by a constant does not affect the standard deviation between its periods nor its correlation with other series. We then opt for VPVOBARSA. It allows for comparisons not only of variation (standard deviation) and comovements (correlation) but also of magnitude, since the outputs of all countries will be expressed in the same unit (US dollars).

== Civilian Employment Series <app:employment>
BKK's quarterly data on civilian employment come from OECD's #emph[Main Economic Indicators];. Yet, the #emph[Main Economic Indicators];'s data on quarterly civilian employment are not available on OECD's website as of this writing. Instead, OECD provides quarterly data on employed population in its #emph[Short-Term Labour Market Statistics];. As can be seen from @tab:emptimespan, the length of the series of some countries available in #emph[Short-Term Labour Market Statistics] are too short for the comparison with BKK's results to be reasonable. Fortunately, data on civilian employment from OECD's #emph[Main Economic Indicators] were available for France, United Kingdom and Italy in the Federal Reserve Bank of St. Louis website#footnote[#link("https://research.stlouisfed.org/");];, which allowed us to expand these series. Similar data for Switzerland and the European aggregate were not found and given the short length of #emph[Short-Term Labour Market Statistics];'s series for these two, we opted to exclude from our calculations of comovements of civilian employment.

#employment-table() <tab:emptimespan>

Before deciding whether to combine the #emph[Short-Term Labour Market Statistics] and #emph[Main Economic Indicators] series on employment, we have plotted in @fig:emp the series together to see how similar they are. It turns out they are similar enough. For this reason and in order to obtain longer series, we have decided to chain the two series for France, United Kingdom and Italy. We multiply the #emph[Short-Term Labour Market] series by a factor such that both series have the same value at the period for which the #emph[Main Economic Indicators] series has its last observation. The two series were then merged with #emph[Short-Term Labour Market] complementing the missing values of #emph[Main Economic Indicators];. The length of the resulting time series can be seen in @tab:timespan.

#employment-figure() <fig:emp>
