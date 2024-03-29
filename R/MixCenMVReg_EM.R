#' Censored Mixture Multivariate Regression EM
#'
#' @param Y the response variables matrix, N x p.
#' @param C censored ID matrix, N x p, -1 means left, 0 means observed and 1 means right censored.
#' @param X covariates matrix, N x d, with d-1 covariates.
#' @param G the given number of groups.
#' @param Max.iter the maximum iteration numbers.
#' @param pie_hat a vector of initialized Mixing porportions.
#' @param beta_hat a list of initialized Beta matrices, each matrix with d x p, with p response variables and d-1 covariates.
#' @param sigma_hat a list of initialized Sigma matrices, each matrix with p x p.
#' @param diff.tol the judgement standard of convergence, default value is 1e-3.
#' @param print whether to print the outcome.
#' @param init_class initial partition, which needs to be factor format.
#' @param calc_cov whether to calculate the covariance matrix.
#'
#' @return Function outputs a list including the following:
#' \describe{
#'       \item{\code{Iterations}}{The number of iterations of EM in the process.}
#'       \item{\code{Converged}}{Whether it is converged or not.}
#'       \item{\code{LogLik}}{the LogLikelihood for the model fitting.}
#'       \item{\code{AIC}}{Akaike's Information Criterion}
#'       \item{\code{BIC}}{Bayesian Information Criterion}
#'       \item{\code{ICL}}{Integrated Complete-data Likelihood Criterion}
#'       \item{\code{Pie}}{A vector of estimated Mixing porportions}
#'       \item{\code{Beta}}{A list of estimated Coefficient matrices}
#'       \item{\code{Sigma}}{a list of estimated initialized Covariance matrices}
#'       \item{\code{Posterior}}{Posterior probability for each observation in each class}
#'       \item{\code{Class}}{The predicted outcome of each observation}
#'       \item{\code{obs_Info}}{false if choose calc_cov=false}
#'       \item{\code{Cov}}{cov matrix}
#' }
#'
#' @import matrixStats
#' @export
#'
MixCenMVReg_EM=function(Y, C, X, G=2, Max.iter=1000,
                        pie_hat=NA, beta_hat=NA, sigma_hat=NA, diff.tol=1e-3,
                        print=TRUE, init_class=NA, calc_cov=FALSE){


  N=dim(Y)[1] # the number of observations
  P=dim(Y)[2] # the dimension of response variables
  D=dim(X)[2] # we have d-1 covariates

  if(is.na(sum(as.integer(init_class)))==FALSE){
      G=length(levels(init_class))  # get the number of groups from init_class
  }

  if(is.null(colnames(Y))){
    colnames(Y)=paste(rep('Y',P), 1:P, sep="_") # give the column names for input Y.
  }

  initial=FALSE

  if(all(is.na(pie_hat)==FALSE) & all(is.na(beta_hat)==FALSE) & all(is.na(sigma_hat)==FALSE)){

    initial=TRUE # all the initial parameter matrices have values.

    if(length(beta_hat)==length(sigma_hat) & length(beta_hat)==length(pie_hat)){
      G=length(beta_hat) # the length means the number of groups.
    } else {
      stop("Intial pie, beta, sigma lengths are different")
    }


    mu_hat=list()
    for(g in 1:G){
      mu_hat[[g]]=X%*%beta_hat[[g]] # get the gth group Y_hat with N x p matrix.
    }
  }


  all_obs.LogLik=c(-Inf) # -Inf = likelihood to 0.

  # set initial iteration number:
  iter=0
  diff=Inf
  # set initial conditional probabilities:
  # ind_density=matrix(NA,nrow=N,ncol=G) #individual contribution to likelihood (NxK)
  log.ind_density=matrix(NA,nrow=N,ncol=G)
  while(iter<Max.iter & diff>diff.tol){
    # print(iter)

    if(iter==0 & initial==FALSE){ # not given initial parameters

      ## E-step: computing the conditional posterior probabilities tau_hat

      ### First assign every one to be 1/G or a very small value
      #             tau_hat=matrix(rep(1/G,N*G), nrow=N, ncol=G)
      # tau_hat=matrix(rep(0,N*G), nrow=N, ncol=G)
      tau_hat=matrix(rep(1e-3,N*G), nrow=N, ncol=G) # set a small number in the matrix N x G.

      if(is.na(sum(as.integer(init_class)))){  # if exist NA in given class or not given class.

          ### Then randomly assign every one to be 1/G
          subsample=sample(1:N,round(N/10),replace=FALSE)
          tau_hat[subsample,]=t(rmultinom(round(N/10), 1, rep(1,G)/G))

      }else{
          ### Assign the initial class label if the label is provided
          for(g in 1:G){
              tau_hat[init_class==(levels(init_class)[g]),g]=1
          }

      }
      pie_hat=apply(tau_hat,2,mean) # set the initial pie_hat with given class when initial parameters are not given.

      mu_hat=list()
      beta_hat=list()
      sigma_hat=list()
      for(g in 1:G){
        # mu_hat[[g]]=tau_hat[,g]*Y

        beta_hat[[g]]=solve(t(X)%*%diag(tau_hat[,g])%*%X)%*%t(X)%*%diag(tau_hat[,g])%*%Y   # the beta calculation from linear model, which is also used in EM.
        mu_hat[[g]]=X%*%beta_hat[[g]]  # estimated Y, N x p, calculated by X and est.beta, which is seemed as the mean of the different groups.
        # sigma_hat[[g]]=cov(tau_hat[,g]*Y)
        # sigma_hat[[g]]=cov(tau_hat[,g]*(Y-mu_hat[[g]]))
        sigma_hat[[g]]=cov.wt(as.matrix(Y-mu_hat[[g]]),tau_hat[,g])$cov  # weighted covariance.
      }

#       beta_hat=list()
#       for(g in 1:G){

#       }

#       sigma_hat=list()
#       for(g in 1:G){
#         sigma_hat[[g]]=cov(tau_hat[,g]*Y)
#       }
      # print(beta_hat)
      # print(sigma_hat)
    }else{   # we have the initial parameters.

      for(g in 1:G){
        ## E-step: computing individual observation's contribution to the likelihood
        # ind_density[,g]=pie_hat[g]*mapply(eval_density,
        #                                   y=split(t(Y), rep(1:N, each = P)),
        #                                   c=split(t(C), rep(1:N, each = P)),
        #                                   m=split(t(mu_hat[[g]]), rep(1:N, each = P)),
        #                                   MoreArgs=list(v=sigma_hat[[g]]))
        log.ind_density[,g]=log(pie_hat[g])+mapply(eval_density,  #function from util.R
                                                   y=split(t(Y), rep(1:N, each = P)),
                                                   c=split(t(C), rep(1:N, each = P)),
                                                   m=split(t(mu_hat[[g]]), rep(1:N, each = P)),
                                                   MoreArgs=list(v=sigma_hat[[g]]))
      }   #log.ind_density NxG

        # because some of the values are tooo small
      log.ind_density[is.infinite(log.ind_density)]=-999
      # print(any(is.na(log.ind_density)))
      # print(dim(log.ind_density))
      # print(log.ind_density)
      # print(apply(log.ind_density,1,logSumExp))
      # print(str(apply(log.ind_density,1,logSumExp)))
      # print(dim(apply(log.ind_density,1,logSumExp)))
      ## E-step: computing the conditional posterior probabilities tau_hat
      # tau_hat=ind_density/apply(ind_density,1,sum) #(NxG)
      new_tau_hat=exp(sweep(log.ind_density, 1, apply(log.ind_density,1,matrixStats::logSumExp)))
      # tau_hat[is.na(tau_hat)]=1/G # adjust the nans

      # tau_hat[tau_hat< 1e-300]=1e-300 # adjust the 0

      # tau_hat[is.na(tau_hat)]=1e-300 # adjust the nans
      # Evaluate Likelihood using the ind_density for convenience
      # obs.LogLik=sum(log(apply(ind_density,1,sum)))

      obs.LogLik=sum(apply(log.ind_density,1,matrixStats::logSumExp))

      # if(length(all_obs.LogLik)>1){
      #    if(obs.LogLik<tail(all_obs.LogLik, n=1)){
      #         message('Warning: numeric precision of conditional truncated probability may have lowered, return max Loglik stored')
      #         break
      #     }else{
      #         all_obs.LogLik=append(all_obs.LogLik,obs.LogLik)
      #         tau_hat=new_tau_hat
      #     }
      # }else{
      #    all_obs.LogLik=append(all_obs.LogLik,obs.LogLik)
      #    tau_hat=new_tau_hat
      # }


      all_obs.LogLik=append(all_obs.LogLik,obs.LogLik)
      tau_hat=new_tau_hat
      ## M-step: Update pie_hat
      new_pie_hat=apply(tau_hat,2,mean)
      diff=max(abs(pie_hat-new_pie_hat))
      pie_hat=new_pie_hat

      ## M-step: Update beta_hat
      Y_star=list()
      for(g in 1:G){
        Y_star[[g]]=t(mapply(eval_ystar,
                             y=split(t(Y), rep(1:N, each = P)),
                             c=split(t(C), rep(1:N, each = P)),
                             m=split(t(mu_hat[[g]]), rep(1:N, each = P)), MoreArgs=list(v=sigma_hat[[g]])))
        if(P==1){ # Fix the problem when P=1 so that mapply give a transposed result
          Y_star[[g]]=t(Y_star[[g]])
        }
        colnames(Y_star[[g]])=colnames(Y)

        new_beta_hat=solve(t(X)%*%diag(tau_hat[,g])%*%X)%*%t(X)%*%diag(tau_hat[,g])%*%Y_star[[g]]
        diff=max(diff,max(abs(beta_hat[[g]]-new_beta_hat)))
        beta_hat[[g]]=new_beta_hat

        mu_hat[[g]]=X%*%beta_hat[[g]]
      }
      # print(mu_hat)
      # print(sigma_hat)
      ## M-step: Update sigma_hat
      S_star=list()
      for(g in 1:G){

        S_star[[g]]=t(Y_star[[g]]-mu_hat[[g]])%*%(tau_hat[,g]*(Y_star[[g]]-mu_hat[[g]]))/sum(tau_hat[,g])

        r=mapply(eval_r,
                 y=split(t(Y), rep(1:N, each = P)),
                 c=split(t(C), rep(1:N, each = P)),
                 m=split(t(mu_hat[[g]]), rep(1:N, each = P)), MoreArgs=list(v=sigma_hat[[g]]))

        R=matrix(apply(t(r)*tau_hat[,g],2,sum),nrow=P,ncol=P)/sum(tau_hat[,g])

        new_sigma_hat=S_star[[g]]+R
        new_sigma_hat=(new_sigma_hat+t(new_sigma_hat))/2

        diff=max(diff,max(abs(sigma_hat[[g]]-new_sigma_hat)))
        sigma_hat[[g]]=new_sigma_hat
      }
    }

    iter = iter + 1

    if(min(unlist(lapply(sigma_hat,diag)))<1e-10){
            message("EM stopped becaused of degenerating solution!")
            break
    }
  }


  if(calc_cov==TRUE){

      if(G>1){
        score_pie=list()
        for(g in 1:(G-1)){
          score_pie[[g]]=tau_hat[,g]/pie_hat[g]-tau_hat[,G]/pie_hat[G]
        }
        score_pie=do.call('cbind',score_pie)
        colnames(score_pie)=combine(c("PIE"),1:(G-1))

      }else{
        score_pie=NULL
      }


      score_beta=list()
      for(g in 1:G){

        score_beta[[g]]=t(mapply(eval_betascore,
                                 yc=split(t((tau_hat[,g]*(Y_star[[g]]-mu_hat[[g]])%*%solve(sigma_hat[[g]]))), rep(1:N, each = P)),
                                 x=split(t(X), rep(1:N, each = D))))

        colnames(score_beta[[g]])=combine(c("BETA"),colnames(Y),colnames(X),c(g))
      }
      score_beta=do.call('cbind',score_beta)

      score_sigma=list()
      for(g in 1:G){
          # score_sigma[[g]]=tau_hat[,g]*(S_star[[g]]-(sigma_hat[g])^2)/(2*(sigma_hat[g])^4)
          s=split(t(Y_star[[g]]-mu_hat[[g]]), rep(1:N, each = P))
          
          r=mapply(eval_r,
                 y=split(t(Y), rep(1:N, each = P)),
                 c=split(t(C), rep(1:N, each = P)),
                 m=split(t(mu_hat[[g]]), rep(1:N, each = P)), MoreArgs=list(v=sigma_hat[[g]]))
          # rr=matrix(apply(t(r)*tau_hat[,g],2,sum),nrow=P,ncol=P)
          # rr=mapply(matrix,split(t(r), rep(1:N, each = P)),nrow=P,ncol=P)
          # xx=solve(sigma_hat[[g]])%*%(ss+rr-sigma_hat[[g]])%*%solve(sigma_hat[[g]])*0.5
          # rr=lapply(split(t(r), rep(1:N, each = P)), matrix, nrow=P,ncol=P) 
          rr=lapply(split(r, rep(1:N, each = P^2)), matrix, nrow=P,ncol=P)
          
          score_sigma[[g]]=list()
          for(i in 1:N){
              score_sigma[[g]][[i]]=0.5*tau_hat[i,g]*solve(sigma_hat[[g]])%*%(as.matrix(s[[i]])%*%t(as.matrix(s[[i]]))+rr[[i]]-sigma_hat[[g]])%*%solve(sigma_hat[[g]])
          }
          score_sigma[[g]]=t(mapply(as.vector,score_sigma[[g]]))
          
          colnames(score_sigma[[g]])=combine(c("SIGMA"),colnames(Y),colnames(Y),c(g))
          
          sigma_m=matrix(1:P^2, P, P)
          score_sigma[[g]]=score_sigma[[g]][,sort(c(sigma_m[lower.tri(sigma_m)],diag(sigma_m)))]
      }
      # print(score_sigma)
      score_sigma=do.call('cbind',score_sigma)

      # all_score=cbind(score_pie,score_beta)
      # all_score=cbind(score_beta)
      if(is.null(score_pie)){
          all_score=cbind(score_beta,score_sigma)
      }else{
          all_score=cbind(score_pie,score_beta,score_sigma)
      }

      obs_Info=t(all_score)%*%all_score

      if(any(eigen(obs_Info)$values<=1e-6)){
        cov_notPD=TRUE
        print('The Cov matrix for coefficients is not positive definite')

      }else{
        cov_notPD=FALSE
        cov=solve(obs_Info)
      }

  }else{
      obs_Info=NA
      cov_notPD=TRUE
      print('The Info matrix for coefficients is not computed')

  }

  if(iter<Max.iter & diff<=diff.tol){
    converge_=TRUE
  }else{
    converge_=FALSE
  }

  names(pie_hat)=paste0("pie",1:G)
  names(beta_hat)=paste0("beta",1:G)
  names(sigma_hat)=paste0("sigma",1:G)

  if(print){
    print(paste0("Total Iteration = ",toString(iter)))
    print(paste0("Convergence = ",toString(converge_)))
    print(paste0("LogLik = ",toString(round(tail(all_obs.LogLik, n=1),3))))
    print(pie_hat)
    print(beta_hat)
    print(sigma_hat)
    #         print(obs_Info)
    plot(all_obs.LogLik[-1],xlab="Iterations", ylab="Log-Likelihood",)
  }

  LogLik=tail(all_obs.LogLik, n=1)
  nparm=length(as.vector(unlist(beta_hat)))+length(unique(as.vector(unlist(sigma_hat))))+length(pie_hat)-1

  POST_PROB=tau_hat
  POST_PROB[POST_PROB < 1e-8] = 1e-8
  entropy=-sum(POST_PROB*log(POST_PROB))
  entropy.rsquare=1 - entropy/(N*log(G))

  AIC=-2*LogLik+nparm*2
  BIC=-2*LogLik+nparm*log(N)
  ICL=BIC+2*entropy



  OUTPUT=list()

  OUTPUT[[1]]=iter
  OUTPUT[[2]]=(iter<Max.iter)
  OUTPUT[[3]]=LogLik
  OUTPUT[[4]]=AIC
  OUTPUT[[5]]=BIC
  OUTPUT[[6]]=ICL

  OUTPUT[[7]]=pie_hat
  OUTPUT[[8]]=beta_hat
  OUTPUT[[9]]=sigma_hat
  OUTPUT[[10]]=tau_hat
  OUTPUT[[11]]=apply(tau_hat,1,eval_class)
  if(cov_notPD){
    OUTPUT[[12]]=obs_Info
    names(OUTPUT)<-c("Iterations", "Converged", "LogLik","AIC", "BIC", "ICL","Pie", "Beta", "Sigma", "Posterior","Class","obs_Info")

  }else{
    OUTPUT[[12]]=cov
    names(OUTPUT)<-c("Iterations", "Converged", "LogLik","AIC", "BIC", "ICL","Pie", "Beta", "Sigma", "Posterior","Class","Cov")
  }


  return(OUTPUT)

}
