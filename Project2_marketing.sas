

libname pmlr '/folders/myfolders/sasproject';
proc contents data=pmlr.pva_raw_data;
run;

data pva(drop=Control_number);
   set pmlr.pva_raw_data;
run;

%let ex_inputs= MONTHS_SINCE_ORIGIN 
DONOR_AGE IN_HOUSE INCOME_GROUP PUBLISHED_PHONE
MOR_HIT_RATE WEALTH_RATING MEDIAN_HOME_VALUE
MEDIAN_HOUSEHOLD_INCOME PCT_OWNER_OCCUPIED
PER_CAPITA_INCOME PCT_MALE_MILITARY 
PCT_MALE_VETERANS PCT_VIETNAM_VETERANS 
PCT_WWII_VETERANS PEP_STAR RECENT_STAR_STATUS
FREQUENCY_STATUS_97NK RECENT_RESPONSE_PROP
RECENT_AVG_GIFT_AMT RECENT_CARD_RESPONSE_PROP
RECENT_AVG_CARD_GIFT_AMT RECENT_RESPONSE_COUNT
RECENT_CARD_RESPONSE_COUNT LIFETIME_CARD_PROM 
LIFETIME_PROM LIFETIME_GIFT_AMOUNT
LIFETIME_GIFT_COUNT LIFETIME_AVG_GIFT_AMT 
LIFETIME_GIFT_RANGE LIFETIME_MAX_GIFT_AMT
LIFETIME_MIN_GIFT_AMT LAST_GIFT_AMT
CARD_PROM_12 NUMBER_PROM_12 MONTHS_SINCE_LAST_GIFT
MONTHS_SINCE_FIRST_GIFT;

/*Check the mean, minimum, maximum, and count of missing for each numeric input*/

proc means data=pva n nmiss mean std min max;
   var &ex_inputs;
run;

/*check frequency for character variables*/
proc freq data=pva;
   tables _character_ target_b / missing;
run;


/*Create missing value indicators for inputs that have missing values.*/
/*
missing columns are: DONOR_AGE INCOME_GROUP WEALTH_RATING;
*/

data pva(drop=i);
   set pva;
   /* name the missing indicator variables */
   array mi{*} mi_DONOR_AGE mi_INCOME_GROUP 
               mi_WEALTH_RATING;
   /* select variables with missing values */
   array x{*} DONOR_AGE INCOME_GROUP WEALTH_RATING;
   do i=1 to dim(mi);
      mi{i}=(x{i}=.);
   end;
run;
/*Impute missing value to a new dataset pva1*/

proc stdize data=pva 
		  method=median  /* or MEAN, MINIMUM, MIDRANGE, etc. */
          reponly  /* only replace; do not standardize */
          out=pva1;
   var DONOR_AGE INCOME_GROUP WEALTH_RATING;  /* you can list multiple variables to impute */
run;

/*
Split the imputed data set into training and test data sets. 
Use 70% of the data for each data
set role. Stratify on the target variable.*/
proc sort data=pva1 out=pva1;
   by target_b;
run;

proc surveyselect noprint
                  data=pva1
                  samprate=.7 
                  out=pva2
                  seed=27513
                  outall;
   strata target_b;
run;

data pva_train pva_test;
   set pva2;
   if selected then output pva_train;
   else output pva_test;
run;

/* use proc freq to check whether train is 70% and 30% for test, and response rate is the same*/
proc freq data=pva_train;
table target_b;
run;

proc freq data=pva_test;
table target_b;
run;





/*create macro variable which has all the independent variables we need*/

%let ex_screened=
LIFETIME_CARD_PROM       LIFETIME_MIN_GIFT_AMT   PER_CAPITA_INCOME
mi_INCOME_GROUP   
RECENT_RESPONSE_COUNT    PCT_MALE_MILITARY
DONOR_AGE                PCT_VIETNAM_VETERANS    MOR_HIT_RATE
PCT_OWNER_OCCUPIED       PCT_MALE_VETERANS       PUBLISHED_PHONE
WEALTH_RATING MONTHS_SINCE_LAST_GIFT   RECENT_STAR_STATUS      LIFETIME_GIFT_RANGE
INCOME_GROUP             IN_HOUSE  
RECENT_AVG_GIFT_AMT     PCT_WWII_VETERANS
LIFETIME_GIFT_AMOUNT     PEP_STAR                mi_DONOR_AGE
RECENT_AVG_CARD_GIFT_AMT RECENT_CARD_RESPONSE_PROP
;

/*Use the Spearman correlation coefficients to screen the inputs with the
least evidence of a relationship with the target*/
proc corr data=pva_train spearman rank;
   var &ex_screened;
   with target_b;
run;


/*
Fit a logistic regression model with the FAST BACKWARD method. Use the macro variable
ex_screened to represent all independent variables*/

proc logistic data=pva_train des;
   model target_b = &ex_screened
   /selection=backward fast;
run;

/*
Fit a logistic regression model with the FAST Stepwise method. Use the macro variable
ex_screened to represent all independent variables*/

proc logistic data=pva_train des;
   model target_b = &ex_screened
   /selection=stepwise fast best=1;
run;

/*let's assume the final variable you select are:
MONTHS_SINCE_LAST_GIFT: months since most recent donation
INCOME_GROUP: income bracket, from 1 to 7
RECENT_AVG_GIFT_AMT: average donation amount
PEP_STAR: flag to identify consecutive donors
RECENT_CARD_RESPONSE_PROP: proportion of responses to promotions

Let's check ROC curve for this model and use this model to score
pva_test
Also, check average of p_1 in scored_test
*/

proc logistic data=pva_train des plots=ROC;
model target_b = 
MONTHS_SINCE_LAST_GIFT
INCOME_GROUP
RECENT_AVG_GIFT_AMT
PEP_STAR
RECENT_CARD_RESPONSE_PROP;
score data = pva_test out=scored_test;
run;

proc means data=scored_test;
var p_1;
run;
