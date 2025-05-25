
*------------------------------------------------------------
* PROJECT: Predicting Tattoo Helpfulness in Colonoscopy
* MODEL: LASSO + Logistic Scoring + AUC + Calibration
*------------------------------------------------------------

* STEP 1: Generate binary outcome from Likert score (1–5)
gen tattoo_helpful = (tattoo_helpful_score >= 4) if !missing(tattoo_helpful_score)
label var tattoo_helpful "Tattoo was helpful (Agree or Strongly Agree)"

* STEP 2: LASSO Logistic Regression with Cross-Validation
lasso logit tattoo_helpful  c.lesionsizemm i.lesionlocationall i.proximallocation i.distallocation i.rectum i.lesioninileocecalvalve  i.lesionfibrosisorscarring i.sessileorslightlyelevatedmorphol i.pedunculatedorsemipedunculatedmo i.elevatedborderswithcentraldepres i.nice_class i.colonoscopy_indication, selection(cv, folds(5)) rseed(1234)




* STEP 3: Display selected variables
lassocoef, display(coef, penalized) sort(coef, penalized)

* STEP 4: Predict probabilities from LASSO model
predict double lasso_pred, pr

* STEP 5: Internal Calibration Curve
calibrationbelt tattoo_helpful lasso_pred, devel("internal") cLevel1(0.95) cLevel2(0.99) maxDeg(4) thres(0.95)

* STEP 6: Cross-validated AUC
cvauroc tattoo_helpful lasso_pred, kfold(5) seed(1972) fit detail graphlowess

* STEP 7: Alternative AUC estimate and ROC plot
rocreg tattoo_helpful lasso_pred, bseed(1234)
rocregplot

* STEP 8: Refit simplified logistic model using LASSO-selected variables
logit tattoo_helpful i.colonoscopy_indication i.lesionlocationall i.elevatedborderswithcentraldepres i.lesioninileocecalvalve  i.lesionfibrosisorscarring i.pedunculatedorsemipedunculatedmo i.suspectedmorphology  c.lesionsizemm

* STEP 9: Generate manual scoring equation
gen logit_simple = 1.182508*(colonoscopy_indication==2) + 0.4020261*(colonoscopy_indication==4) + 0.304348*(colonoscopy_indication==8) + 2.45008*(lesionlocationall==2) + 2.031535*(lesionlocationall==3) + 1.567262*(lesionlocationall==4) - 2.099315*(elevatedborderswithcentraldepres==1) - 0.8358958*(lesionfibrosisorscarring==1) - 0.9752882*(pedunculatedorsemipedunculatedmo==1) + 0.1773799*(suspectedmorphology==2) + 0.777*(suspectedmorphology==3) - 0.0694509*lesionsizemm - 0.045359

gen prob_simple = 1 / (1 + exp(-logit_simple))


**Getting cutt off
roctab tattoo_helpful prob_simple, detail
cutpt tattoo_helpful prob_simple, youden 

* STEP 10: ROC + Threshold-Based Prediction
summarize prob_simple
gen predict_tattoo = prob_simple >= 0.462
roctab tattoo_helpful prob_simple, detail graph
rocreg tattoo_helpful prob_simple, bseed(1234)
rocregplot

* STEP 11: Cross-validated AUC of simplified model
cvauroc tattoo_helpful prob_simple, kfold(5) seed(7777) graphlowess

* STEP 12: Calibration for simplified model
calibrationbelt tattoo_helpful prob_simple, devel("internal")  cLevel1(0.95) cLevel2(0.99) maxDeg(4) thres(0.95)

* STEP 13: Confusion matrix
tabulate tattoo_helpful predict_tattoo, matcell(confmat)


* STEP 17: Visualize model predictions

* Bin lesion size in 10 mm intervals
gen size_bin = .
replace size_bin = 1 if lesionsizemm <= 10
replace size_bin = 2 if lesionsizemm >10 & lesionsizemm <= 20
replace size_bin = 3 if lesionsizemm >20 & lesionsizemm <= 30
replace size_bin = 4 if lesionsizemm >30 & lesionsizemm <= 40
replace size_bin = 5 if lesionsizemm >40 & lesionsizemm <= 50
replace size_bin = 6 if lesionsizemm >50 & lesionsizemm <= 60
replace size_bin = 7 if lesionsizemm >60 & lesionsizemm <= 70
replace size_bin = 8 if lesionsizemm >70

label define sizebins 1 "≤10" 2 "11–20" 3 "21–30" 4 "31–40" 5 "41–50" 6 "51–60" 7 "61–70" 8 ">70"
label values size_bin sizebins

* Preserve original dataset
preserve

* Get mean predicted probability by lesion size bin
collapse (mean) prob_simple, by(size_bin)

* Bar chart of mean predicted probabilities by lesion size bin
twoway (bar prob_simple size_bin, barwidth(0.5)), ///
    title("Mean Predicted Probability by Lesion Size Bin") ///
    ylabel(0(0.2)1, angle(0)) ///
    xlabel(1 "≤10" 2 "11–20" 3 "21–30" 4 "31–40" 5 "41–50" 6 "51–60" 7 "61–70" 8 ">70", angle(0)) ///
    ytitle("Mean Predicted Probability") xtitle("Lesion Size (mm)") ///
    legend(off) graphregion(color(white)) bgcolor(white)

* Restore original data
restore

* Box plot: predicted probability by tattoo helpfulness
graph box prob_simple, over(tattoo_helpful) ///
    title("Predicted Probability by Tattoo Helpfulness") ///
    ylabel(0(0.2)1)
	
	* STEP 17 (Alternative): Scatter plot of lesion size vs predicted probability

twoway ///
    (scatter prob_simple lesionsizemm, jitter(1) msymbol(o) msize(small)) ///
    (lowess prob_simple lesionsizemm, bw(0.8) lwidth(medthick)), ///
    title("Predicted Probability vs Lesion Size") ///
    xtitle("Lesion Size (mm)") ///
    ytitle("Predicted Probability of Tattoo Helpfulness") ///
    ylabel(0(0.2)1, angle(0)) ///
    legend(off) graphregion(color(white)) bgcolor(white)


* STEP 18: Confusion matrix
tabulate tattoo_helpful predict_tattoo, matcell(confmat)
