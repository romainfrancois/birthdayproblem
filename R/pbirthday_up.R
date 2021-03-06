##########################################################################
#' Function implementing the calculation of factorial polynomials
#' (x)_m = x! / (x-m+1)!
#'
#' @param x Base
#' @param m index
#' @return (x)_m
#' @noRd
##########################################################################

facpoly <- function(x, m) {
  exp(lfactorial(x) - lfactorial(x-m))
}

######################################################################
#' Variant of \code{pbirthday}, which handles unequal occurrence probabilites
#'
#' This function calculates the probability for at least one collision in a set
#' of n individuals sampled iid. from a vector of length N with
#' occurrence probabilities as given by the vector p. This is an instance
#' of the birthday problem with unequal occurrence probabilities.
#'
#' @param n Size of the set
#' @param prob Vector containing the occurrence probabilities. The length of \code{prob} determines N.
#' @param method A string describing which computational method to use. \code{"R"} (the default) works in acceptable time up to n's of about 30. The \code{"Rcpp"} options works for larger n of moderate size, e.g., n=60 takes about 3 minutes. For larger n or faster computation one can use the \code{"mase1992"} approximation, which is surprisingly accurate.
#'
#' @return A list containing the following elements:
#' \describe{
#'    \item{\code{prob}}{(numeric) The probability for at least one collision}
#'    \item{\code{tList}}{A matrix containing all compositions of singletons,
#'     dubletons, each row has the property sum(row * 1:n) == n.}
#'    \item{...}{}
#' }
#' @importFrom utils read.table
#' @importFrom Rcpp sourceCpp
#' @examples
#' pbirthday(n=26, classes=365, coincident=2)
#' pbirthday_up(n=26L, prob=rep(1/365,365), method="R")$prob
#' pbirthday_up(n=26L, prob=rep(1/365,365), method="Rcpp")$prob
#' @references Mase, S. 1992. “Approximations to the Birthday Problem with Unequal Occurrence Probabilities and Their Application to the Surname Problem in Japan.” Ann. Inst. Stat. Math. 44 (3): 479–99. \url{http://www.ism.ac.jp/editsec/aism/pdf/044_3_0479.pdf}.
#' @references H\enc{ö}{oe}hle, M., Happy pbirthday class of 2016, \url{http://staff.math.su.se/hoehle/blog/2017/02/13/bday.html}.
#' @references H\enc{ö}{oe}hle, M., US Babyname Collisions 1880-2014, \url{http://staff.math.su.se/hoehle/blog/2017/03/01/morebabynames.html}.
#' @export
######################################################################

pbirthday_up <- function(n, prob, method=c("R","Rcpp","mase1992")) {
  ##Check the arguments
  method <- match.arg(method, c("R","Rcpp","mase1992"))
  if (!is.integer(n)) stop("n has to be an integer.")
  if (n>60 & (method %in% c("R","Rcpp"))) {
    warning("n is pretty large. This might take a while. Possibly consider using the 'mase1992' to compute an approximate result.")
  }

  ##P-symmetric funcs
  P <- sapply(seq_len(n), function(x) sum(prob^x))

  if (method == "mase1992") {
    sigma <- c(1,
               sigma_n1 <- exp( -facpoly(n,2)/2 * P[2]),
               exp( facpoly(n,3) * ( -P[2]^2/2 + P[3]/3)),
               exp( facpoly(n,4) * ( -5/6*P[2]^3 * P[2]*P[3] - 1/4*P[4])),
               exp( facpoly(n,5) * ( -7/4*P[2]^4 + 3*P[2]^2*P[3] - P[2]*P[4] + 1/5*P[5] - 1/2*P[3]^2)))
    ##Make sure we don't need to use facpoly(n,x) if n < x
    idx <- min(n,5)
    res <- cumprod(sigma)[idx]
    return(list(prob=1 - res, tList=NA, P=NA,a=NA))
  }

  if (method == "R") {
    ##Make function to compute list of coefs
    source(textConnection(make_tListFunc_syntax(n=n)))
    ##Compute coefs
    tList <- compute_tList()
  }

  if (method == "Rcpp") {
    writeLines(make_tListFunc_syntax_rcpp(n=n),file((theCppFile = paste0(tempfile(),".cpp"))))
    Rcpp::sourceCpp(file=theCppFile)

    ##Run program and store std output to file
    theTempFile <- tempfile()
    sink(theTempFile)
    f <- make_tList_rcpp()
    sink()
    tList <- read.table(file=theTempFile,sep=",")
    if (ncol(tList) != n) { stop("Column numbers and r don't match.") }
  }

  ##Verify results
  stopifnot(rowSums(tList * matrix(1:n,ncol=n,nrow=nrow(tList),byrow=TRUE)) == n)

  ##Might be numerical unstable for large n?
  coefFun <- function(t) {
    factorial(n)*(-1)^(n+sum(t)) / prod( (1:n)^t * factorial(t))
  }

  a <- apply(tList, 1, coefFun)

  Pprod <- apply(tList, 1, function(t) prod(P^ifelse(t>0,t,0)))

  res <- list(prob=1 - sum(a * Pprod),tList=tList, P=P,a=a)
  #Result
  return(res)
}
