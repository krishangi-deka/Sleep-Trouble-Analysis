## This analysis predicts factors affecting sleep from data collected from NHANES : National Health And Nutrition Examination Survey.

library(NHANES)
library(rpart)
library(partykit)
library(dplyr)
library(ROCR)
library(ggplot2)
glimpse(NHANES)


NHANES_new <- NHANES[complete.cases(NHANES$SleepTrouble), ]
str(NHANES_new)
tree <- rpart(SleepTrouble ~ SleepHrsNight + Depressed, data = NHANES_new,
              parms = list(split = "gini"))
plot(as.party(tree),type = "simple")

## The best splits were: sleeping at least 5.5 hours per night, which resulted in a prediction of No sleep trouble; sleeping less than 5.5 hours with no depression resulted in a prediction of no sleep trouble; and sleeping less than 5.5 hours with several or majority of days depressed predicted sleep trouble.


NHANES_new %>%
  filter(is.na(SleepTrouble) == F) %>%
  group_by(SleepTrouble) %>%
  summarise(n = n()) %>%
  mutate(pct = n/sum(n))

set.seed(1234)
r <- nrow(NHANES_new)
test <- sample.int(r, size = round(0.25 * r)) 
train <- NHANES_new[-test, ]
#nrow(train)
#is.na(NHANES_new$SleepTrouble)
test_data <- NHANES_new[test, ] 
#nrow(test_data)



c_tree <- rpart(SleepTrouble ~ SleepHrsNight + Depressed, data = train, 
                parms = list(split = "gini"))
p_tree <- predict(object = c_tree, newdata = test_data, type = "prob")
confusion_matrix <- table(p_tree[,2] >= 0.5,test_data$SleepTrouble)
row.names(confusion_matrix) <- c("No","Yes")
confusion_matrix


sensit_50 <- confusion_matrix[4]/(confusion_matrix[4] + confusion_matrix[3])
print(paste('sensitivity:',sensit_50))
specif_50 <- confusion_matrix[1]/(confusion_matrix[1] + confusion_matrix[2])
print(paste("specificity:",specif_50))
fpr_50 <- 1 - specif_50
print(paste("false positive rate:",fpr_50))
fnr_50 <- 1 - sensit_50
print(paste("false negative rate:",fnr_50))
accuracy_50 <- (confusion_matrix[1] +
                  confusion_matrix[4])/sum(confusion_matrix)
print(paste("Accuracy:",accuracy_50))


confusion_matrix_2 <- table(p_tree[,2] >= 0.25,test_data$SleepTrouble)
row.names(confusion_matrix_2) <- c("No","Yes")
confusion_matrix_2


sensitivity_data2 <- confusion_matrix_2[4]/(confusion_matrix_2[4] + confusion_matrix_2[3])
print(paste('Sensitivity:',sensitivity_data2))   

specificity_data2 <- confusion_matrix_2[1]/(confusion_matrix_2[1] + confusion_matrix_2[2])
print(paste('Specificity:',specificity_data2))    

fpr2 <- 1 - specificity_data2
print(paste('false positive rate:',fpr2))     

fnr <- 1 - sensitivity_data2
print(paste('false negative rate:',fnr))     

accuracy2 <- (confusion_matrix_2[1] 
              + confusion_matrix_2[4])/sum(confusion_matrix_2)
print(paste('accuracy:',accuracy2))


p_tree <- predict(object = tree, newdata = test_data, type = "prob")
predicted <- ROCR::prediction(predictions = p_tree[,2], test_data$SleepTrouble)
perf <- ROCR::performance(predicted, 'tpr', 'fpr')
pf <- data.frame(perf@x.values, perf@y.values) 
names(pf) <- c("fpr", "tpr") 
roc <- ggplot(data = pf, aes(x = fpr, y = tpr)) +
  geom_line(color = "blue") + geom_abline(intercept = 0, slope = 1, lty = 3) + 
  ylab(perf@y.name) + xlab(perf@x.name)
roc

opt.cut <- function(perf){
  cut.ind <- mapply(FUN = function(x,y,p){d=(x-0)^2+(y-1)^2 
  # We compute the distance of all the points from the corner point [1,0]
  ind<- which(d==min(d)) # We find the index of the point that is closest to 
  #the corner
  c(recall = y[[ind]], specificity = 1-x[[ind]],cutoff = p[[ind]])},perf@x.values, 
  perf@y.values,perf@alpha.values)
}
new_cut <- opt.cut(perf)
new_cut
## Cutoff is at 0.408. Since better recall and lower FPR.


tree_full <- rpart(SleepTrouble ~ ., data = train, parms = list(split = "gini"))
predicted_tree_full <- predict(object = tree_full, newdata = test_data,type = "prob")
confusion_matrix3 <- table(predicted_tree_full[,2] >= 0.5,test_data$SleepTrouble)
row.names(confusion_matrix3) <- c("No","Yes")
confusion_matrix3

Acc<-(confusion_matrix3[1] + confusion_matrix3[4])/sum(confusion_matrix3)
Acc  

pred <- ROCR::prediction(predictions = predicted_tree_full[,2], 
                         test_data$SleepTrouble)
perf <- ROCR::performance(pred, 'tpr', 'fpr')
pf_full <- data.frame(perf@x.values, perf@y.values) 
names(pf_full) <- c("fpr", "tpr")
rbind(pf_full,pf)
c(rep("All Vars",7),rep("Two Vars",3))
plot_dat <- cbind(rbind(pf_full,pf), model = c(rep("All Vars",7),
                                               rep("Two Vars",3)))
ggplot(data = plot_dat, aes(x = fpr, y = tpr, colour = model)) + 
  geom_line() + geom_abline(intercept = 0, slope = 1, lty = 3) + 
  ylab(perf@y.name) + 
  xlab(perf@x.name)
## Both trees have almost the same performance. Even though ROC curves can be seen overlapping but accuracy of model with all variables is slighlty more than the model with two variables.Difference in Accuracy: 0.758-0.746 = 0.012


