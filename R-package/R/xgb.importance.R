#' Show importance of features in a model
#' 
#' Read a xgboost model text dump. 
#' Can be tree or linear model (text dump of linear model are only supported in dev version of \code{Xgboost} for now).
#' 
#' @importFrom data.table data.table
#' @importFrom data.table setnames
#' @importFrom data.table :=
#' @importFrom magrittr %>%
#' @param feature_names names of each feature as a character vector. Can be extracted from a sparse matrix (see example). If model dump already contains feature names, this argument should be \code{NULL}.
#' @param filename_dump the path to the text file storing the model. Model dump must include the gain per feature and per tree (\code{with.stats = T} in function \code{xgb.dump}).
#' @param model generated by the \code{xgb.train} function. Avoid the creation of a dump file.
#'
#' @return A \code{data.table} of the features used in the model with their average gain (and their weight for boosted tree model) in the model.
#'
#' @details 
#' This is the function to understand the model trained (and through your model, your data).
#' 
#' Results are returned for both linear and tree models.
#' 
#' \code{data.table} is returned by the function. 
#' There are 3 columns :
#' \itemize{
#'   \item \code{Features} name of the features as provided in \code{feature_names} or already present in the model dump.
#'   \item \code{Gain} contribution of each feature to the model. For boosted tree model, each gain of each feature of each tree is taken into account, then average per feature to give a vision of the entire model. Highest percentage means important feature to predict the \code{label} used for the training ;
#'   \item \code{Cover} metric of the number of observation related to this feature (only available for tree models) ;
#'   \item \code{Weight} percentage representing the relative number of times a feature have been taken into trees. \code{Gain} should be prefered to search the most important feature. For boosted linear model, this column has no meaning.
#' }
#' 
#' 
#' @examples
#' data(agaricus.train, package='xgboost')
#' data(agaricus.test, package='xgboost')
#' 
#' #Both dataset are list with two items, a sparse matrix and labels 
#' #(labels = outcome column which will be learned). 
#' #Each column of the sparse Matrix is a feature in one hot encoding format.
#' train <- agaricus.train
#' test <- agaricus.test
#' 
#' bst <- xgboost(data = train$data, label = train$label, max.depth = 2, 
#'                eta = 1, nround = 2,objective = "binary:logistic")
#' 
#' #agaricus.test$data@@Dimnames[[2]] represents the column names of the sparse matrix.
#' xgb.importance(agaricus.test$data@@Dimnames[[2]], model = bst)
#' 
#' @export
xgb.importance <- function(feature_names = NULL, filename_dump = NULL, model = NULL){  
  if (!class(feature_names) %in% c("character", "NULL")) {	   
    stop("feature_names: Has to be a vector of character or NULL if the model dump already contains feature name. Look at this function documentation to see where to get feature names.")
  }
  
  if (!(class(filename_dump) %in% c("character", "NULL") && length(filename_dump) <= 1)) {
    stop("filename_dump: Has to be a path to the model dump file.")
  }
  
  if (!class(model) %in% c("xgb.Booster", "NULL")) {
    stop("model: Has to be an object of class xgb.Booster model generaged by the xgb.train function.")
  }
  
  if(is.null(model)){
    text <- readLines(filename_dump)  
  } else {
    text <- xgb.dump(model = model, with.stats = T)
  } 
  
  if(text[2] == "bias:"){
    result <- readLines(filename_dump) %>% linearDump(feature_names, .)
  }  else {
    result <- treeDump(feature_names, text = text)
  }
  result
}

treeDump <- function(feature_names, text){  
  result <- xgb.model.dt.tree(feature_names = feature_names, text = text)[Feature!="Leaf",.(Gain = sum(Quality), Cover = sum(Cover), Frequence = .N), by = Feature][,`:=`(Gain=Gain/sum(Gain),Cover=Cover/sum(Cover),Frequence=Frequence/sum(Frequence))][order(-Gain)]
  
  result  
}

linearDump <- function(feature_names, text){
  which(text == "weight:") %>% {a=.+1;text[a:length(text)]} %>% as.numeric %>% data.table(Feature = feature_names, Weight = .)
}

# Avoid error messages during CRAN check.
# The reason is that these variables are never declared
# They are mainly column names inferred by Data.table...
globalVariables(".")