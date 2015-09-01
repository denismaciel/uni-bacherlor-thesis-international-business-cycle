#BKK International Business Cycle

The statistical analysis of the paper was all done using the software R. R can be downloaded at https://www.r-project.org for free. 

##Files containing code (.R)

The file that aggregates almost all code is +Code.R. The reader should run it once and be able to reproduce the most relevant results of the paper. After running +Code.R, the reader can access the most relevant results by runining the file Central Results.R, where each R object is accompained by a short explanation.

By running +Code.R, the following code files will also be automatically be run: 

###Code.R      
	* bkk-con.R      
	* bkk-emp.R      
	* bkk-gdp.R      
	* bkk-gov.R      
	* bkk-inv.R      
	* bkk-netexp.R      
	* bkk-sol.R      
	* Averaged Correlations.R 

The following files must be run independently be the reader after running +Code.R: 

###Files containg plots
       	* Fig Correlation Distribution.R – Plot with the distribution of cross-country 
correlation of output and consumption
      	* Fig Cross GDPCor Plot.R – Plot of cross-country correlations of output and consumption
	    * Fig HP Filter Image.R – Plot of filtered GDP 

This file contain the code used to decide which measure to use (Appendix A of the paper) Which measure to use?.R 

###Data Files (.csv)
  * Data from OECD’s National Accounts bkk-consumption.csv
  * bkk-employment.csv 
  * bkk-gdp.csv 
  * bkk-government.csv
  * bkk-investment.csv 
  * bkk-netexports.csv 

GDP with all measures available at OECD gdp-measure-choice.csv 

OECD’s Main Economic Indicators. Downloaded from FRED St. Louis’ website.  
* FRAEMPTOTQISMEI.csv 
* GBREMPTOTQPSMEI.csv 
* ITAEMPTOTQPSMEI.csv 