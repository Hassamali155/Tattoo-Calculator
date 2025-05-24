
*------------------------------------------------------------
* PROJECT: Predicting Tattoo Helpfulness in Colonoscopy
* MODEL: LASSO + Logistic Scoring + AUC + Calibration
*------------------------------------------------------------

* STEP 1: Generate binary outcome
gen tattoo_helpful = (tattoo_helpful_score >= 4) if !missing(tattoo_helpful_score)
label var tattoo_helpful "Tattoo was helpful (Agree or Strongly Agree)"

* STEP 2: LASSO Logistic Regression with Cross-Validation
lasso logit tattoo_helpful c.lesionsizemm i.lesionlocationall i.proximallocation i.distallocation i.rectum i.lesioninileocecalvalve i.lesionfibrosisorscarring i.sessileorslightlyelevatedmorphol  i.pedunculatedorsemipedunculatedmo i.elevatedborderswithcentraldepres i.nice_class i.colonoscopy_indication, selection(cv, folds(5)) rseed(1234)

* STEP 3: Display selected variables
lassocoef, display(coef, penalized) sort(coef, penalized)

* STEP 4: Predict probabilities from LASSO model
predict double lasso_pred, pr

* STEP 5: Internal Calibration Curve
calibrationbelt tattoo_helpful lasso_pred, devel("internal") cLevel1(0.95) cLevel2(0.99) maxDeg(4) thres(0.95)

* STEP 6: Cross-validated AUC
cvauroc tattoo_helpful lasso_pred, kfold(5) seed(1972) fit detail graphlowess

* STEP 7: ROC plot with bootstrapped AUC
rocreg tattoo_helpful lasso_pred, bseed(1234)
rocregplot

* STEP 8: Refit simplified logistic model
logit tattoo_helpful i.colonoscopy_indication i.lesionlocationall i.elevatedborderswithcentraldepres  i.lesioninileocecalvalve i.lesionfibrosisorscarring i.pedunculatedorsemipedunculatedmo  i.nice_class c.lesionsizemm

* STEP 9: Manual prediction score
gen logit_simple = 1.124082*(colonoscopy_indication==2) + 0.3436568*(colonoscopy_indication==4) + ///
    0.5626844*(colonoscopy_indication==8) + 1.242918*(lesionlocationall==2) + ///
    0.7863201*(lesionlocationall==3) + 0.3672023*(lesionlocationall==4) - ///
    1.234363*(lesionlocationall==5) - 2.151012*(elevatedborderswithcentraldepres==1) - ///
    1.36939*(lesioninileocecalvalve==1) - 0.8928441*(lesionfibrosisorscarring==1) - ///
    1.030423*(pedunculatedorsemipedunculatedmo==1) + 0.2012144*(nice_class==2) + ///
    0.8903706*(nice_class==3) - 0.0747445*lesionsizemm + 1.359816
gen prob_simple = 1 / (1 + exp(-logit_simple))

* STEP 10: Threshold-Based Prediction
summarize prob_simple
gen predict_tattoo = prob_simple >= 0.462
roctab tattoo_helpful prob_simple, detail graph
rocreg tattoo_helpful prob_simple, bseed(1234)
rocregplot

* STEP 11: Cross-validated AUC for simplified model
cvauroc tattoo_helpful prob_simple, kfold(5) seed(7777) graphlowess

* STEP 12: Calibration
calibrationbelt tattoo_helpful prob_simple, devel("internal") cLevel1(0.95) cLevel2(0.99) maxDeg(4) thres(0.95)

* STEP 13: Confusion Matrix
tabulate tattoo_helpful predict_tattoo, matcell(confmat)

* STEP 14: Visualization
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

preserve
collapse (mean) prob_simple, by(size_bin)

twoway (bar prob_simple size_bin, barwidth(0.5)), ///
    title("Mean Predicted Probability by Lesion Size Bin") ///
    ylabel(0(0.2)1, angle(0)) ///
    xlabel(1 "≤10" 2 "11–20" 3 "21–30" 4 "31–40" 5 "41–50" 6 "51–60" 7 "61–70" 8 ">70", angle(0)) ///
    ytitle("Mean Predicted Probability") xtitle("Lesion Size (mm)") ///
    legend(off) graphregion(color(white)) bgcolor(white)
restore

graph box prob_simple, over(tattoo_helpful) ///
    title("Predicted Probability by Tattoo Helpfulness") ///
    ylabel(0(0.2)1)

twoway ///
    (scatter prob_simple lesionsizemm, jitter(1) msymbol(o) msize(small)) ///
    (lowess prob_simple lesionsizemm, bw(0.8) lwidth(medthick)), ///
    title("Predicted Probability vs Lesion Size") ///
    xtitle("Lesion Size (mm)") ///
    ytitle("Predicted Probability of Tattoo Helpfulness") ///
    ylabel(0(0.2)1, angle(0)) ///
    legend(off) graphregion(color(white)) bgcolor(white)

* Display all categorical variable value labels
foreach var in lesionsizemm lesionlocationall proximallocation distallocation rectum ///
               lesioninileocecalvalve lesionfibrosisorscarring sessileorslightlyelevatedmorphol ///
               pedunculatedorsemipedunculatedmo elevatedborderswithcentraldepres nice_class ///
               colonoscopy_indication {
    tab `var'
}
