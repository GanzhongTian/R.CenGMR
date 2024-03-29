v_censnorm<-function(cen_interval=c(-Inf,Inf), mu=0, sig=1){

  lower=cen_interval[1]
  upper=cen_interval[2]

  A=(lower-mu)/sig; B=(upper-mu)/sig

  if(A==-Inf & B!=Inf){
    logZ=pnorm(B,log.p = T)
    lognumer=dnorm(B,log= T)

    Frac=exp(lognumer-logZ)

    res=sig^2*(1-B*Frac-Frac^2)
  } else if(A!=-Inf & B==Inf){
    logZ=pnorm(A,lower.tail=F, log.p = T)
    lognumer=dnorm(A,log= T)

    Frac=exp(lognumer-logZ)

    res=sig^2*(1+A*Frac-Frac^2)
  } else if(A==-Inf & B==Inf){
    res=sig^2
  }
  return(res)
}



#' Evaluate the density of subject
#'
#' @param y a p-dimension vectors of continous values: observed manifest vars
#' @param c a p-dimension vectors of 0,-1,1 indicating censoring directions
#' @param m a p-dimension vectors of continous values: means estimated by the regression
#' @param v a pxp varcov matrix
#'
#' @return a positive real value of the density
#' @export
#' @import condMVNorm
#' @import mvtnorm
#'
eval_density=function(y,c,m,v){
  ##############################################
  # input:    -y    :a p-dimension vectors of continous values: observed manifest vars
  #           -c    :a p-dimension vectors of 0,-1,1 indicating censoring directions
  #           -m    :a p-dimension vectors of continous values: means
  #           -v    :a pxp varcov matrix
  #
  # output:   a positive real value of the density
  ##############################################
  obslst=which(c==0);cenlst=which(c!=0)
  #     print(length(obslst)+length(cenlst))

  if(length(obslst)>0){

    y_obs=as.vector(as.matrix(y)[obslst])
    m_obs=as.vector(m[obslst])

    v_obs=as.matrix(v[(obslst),(obslst)])

    # f_obs=dmvnorm(y_obs,m_obs,v_obs)
    log.f_obs=mvtnorm::dmvnorm(y_obs,m_obs,v_obs,log=T)
  }else{
    # f_obs=1
    log.f_obs=0
  }

  if(length(cenlst)>0){


    lbd=rep(0,length(cenlst))
    ubd=rep(0,length(cenlst))

    lbd[c[cenlst]==-1]=-Inf
    lbd[c[cenlst]==1]=y[c==1]

    ubd[c[cenlst]==-1]=y[c==-1]
    ubd[c[cenlst]==1]=Inf

    p_cen=pcmvnorm(lower=lbd, upper=ubd, mean=m, sigma=v, dep=cenlst, given=obslst, X=y[obslst])

    if(p_cen<0){
      log.p_cen=-Inf
    }else{
      # log.p_cen=log(pcmvnorm(lower=lbd, upper=ubd, mean=m, sigma=v, dep=cenlst, given=obslst, X=y[obslst]))

      log.p_cen=log(p_cen)
    }
  }else{
    # p_cen=1
    log.p_cen=0
  }
  # return(unname(p_cen*f_obs))
  return(unname(log.p_cen+log.f_obs))
}

# g=2
# i=2
# Y=Y[1:10,];C=C[1:10,];Y=Y[1:10,];M=mu_hat[[g]][1:10,];V=sigma_hat[[g]]
# eval_density(Y[i,],C[i,],M[i,],V)
# Y_star=mapply(eval_density, Y, C, mu_hat[[g]], sigma_hat[[g]])
#' Evaluate the Y-star in multivariate EM
#'
#' @param y a p-dimension vectors of continous values: observed manifest vars
#' @param c a p-dimension vectors of 0,-1,1 indicating censoring directions
#' @param m a p-dimension vectors of continous values: means
#' @param v a pxp varcov matrix
#'
#' @return a p-dimension vector of obs_y or conditional means of cen_y
#' @import MomTrunc
eval_ystar=function(y,c,m,v){
  ############################################################################################
  # input:    -y    :a p-dimension vectors of continous values: observed manifest vars
  #           -c    :a p-dimension vectors of 0,-1,1 indicating censoring directions
  #           -m    :a p-dimension vectors of continous values: means
  #           -v    :a pxp varcov matrix
  #
  # output:   a p-dimension vector of obs_y or conditional means of cen_y
  ############################################################################################
  obslst=which(c==0);cenlst=which(c!=0)
  #     print(length(obslst)+length(cenlst))
  e_y=y

  if(length(cenlst)>0){

    lbd=rep(0,length(cenlst))
    ubd=rep(0,length(cenlst))

    ###################lbd=rep(0,length(cenlst))

    lbd[c[cenlst]==-1]=-Inf
    lbd[c[cenlst]==1]=y[c==1]

    ubd[c[cenlst]==-1]=y[c==-1]
    ubd[c[cenlst]==1]=Inf

    if(length(obslst)>0){

      # lbd;ubd

      D_cen=length(cenlst)

      y_reorder=y[append(cenlst,obslst)]
      c_reorder=c[append(cenlst,obslst)]
      m_reorder=m[append(cenlst,obslst)]


      v_reorder=v[,append(cenlst,obslst)]
      v_reorder=as.data.frame(v_reorder[append(cenlst,obslst),])
      # v_reorder

      v11=as.matrix(v_reorder[1:D_cen,1:D_cen])
      v22=as.matrix(v_reorder[-(1:D_cen),-(1:D_cen)])
      v12=as.matrix(v_reorder[1:D_cen,-(1:D_cen)])

      v_cond=v11-v12%*%solve(v22)%*%t(v12)
      v_cond=(v_cond+t(v_cond))/2 # Force it to be symmetric
      m_cond=as.vector(m_reorder[1:D_cen]+v12%*%solve(v22)%*%(y_reorder[-(1:D_cen)]-m_reorder[-(1:D_cen)]))

      e_y[cenlst]=as.vector(MomTrunc::onlymeanTMD(lbd,ubd,m_cond,v_cond,dist="normal"))

      return(e_y)

    }else{

      e_y[cenlst]=as.vector(MomTrunc::onlymeanTMD(lbd, ubd, m ,v ,dist="normal"))

      return(e_y)
    }

  }else{ # No censoring
    return(e_y)
  }
}

#' Evaluate r in multivariate EM step.
#'
#' @param y a p-dimension vectors of continous values: observed manifest vars.
#' @param c a p-dimension vectors of 0,-1,1 indicating censoring directions.
#' @param m a p-dimension vectors of continous values: means.
#' @param v a pxp varcov matrix.
#'
#' @return a pxp cond_varcov matrix subjected to 0s for the obs features.
#' @import MomTrunc
#'
eval_r=function(y,c,m,v){
  ############################################################################################
  # input:    -y    :a p-dimension vectors of continous values: observed manifest vars
  #           -c    :a p-dimension vectors of 0,-1,1 indicating censoring directions
  #           -m    :a p-dimension vectors of continous values: means
  #           -v    :a pxp varcov matrix
  #
  # output:   a pxp cond_varcov matrix subjected to 0s for the obs features
  ############################################################################################
  obslst=which(c==0);cenlst=which(c!=0)
  #     print(length(obslst)+length(cenlst))
  D_tot=length(y)
  #     print("D_tot")
  #     print(D_tot)

  S_star_reorder=matrix(rep(0,D_tot^2),nrow=D_tot,ncol=D_tot)
  #     print(S_star_reorder)
  if(length(cenlst)>0){

    lbd=rep(0,length(cenlst))
    ubd=rep(0,length(cenlst))

    lbd[c[cenlst]==-1]=-Inf
    lbd[c[cenlst]==1]=y[c==1]

    ubd[c[cenlst]==-1]=y[c==-1]
    ubd[c[cenlst]==1]=Inf

    if(length(obslst)>0){

      # lbd;ubd

      D_cen=length(cenlst)

      y_reorder=y[append(cenlst,obslst)]
      c_reorder=c[append(cenlst,obslst)]
      m_reorder=m[append(cenlst,obslst)]


      v_reorder=v[,append(cenlst,obslst)]
      v_reorder=as.data.frame(v_reorder[append(cenlst,obslst),])

      v11=as.matrix(v_reorder[1:D_cen,1:D_cen])
      v22=as.matrix(v_reorder[-(1:D_cen),-(1:D_cen)])
      v12=as.matrix(v_reorder[1:D_cen,-(1:D_cen)])

      v_cond=unname(v11-v12%*%solve(v22)%*%t(v12))
      v_cond=(v_cond+t(v_cond))/2
      m_cond=as.vector(m_reorder[1:D_cen]+v12%*%solve(v22)%*%(y_reorder[-(1:D_cen)]-m_reorder[-(1:D_cen)]))

      subS_star_reorder=MomTrunc::meanvarTMD(lbd,ubd,m_cond,v_cond,dist="normal")$varcov
      #             subS_star_reorder=MCmeanvarTMD(lbd,ubd,m_cond,v_cond,dist="normal")$EYY

      S_star_reorder=matrix(rep(0,D_tot^2),nrow=D_tot,ncol=D_tot)
      S_star_reorder[1:D_cen,1:D_cen]=subS_star_reorder

      # # colnames(S_star_reorder)=append(cenlst,obslst)
      # # rownames(S_star_reorder)=append(cenlst,obslst)
      # # S_star_reorder

      S_star=S_star_reorder[,match(1:D_tot,append(cenlst,obslst))]
      S_star=S_star[match(1:D_tot,append(cenlst,obslst)),]
      #              print(S_star)
      return(S_star)

    }else{

      S_star=MomTrunc::meanvarTMD(lower=lbd,upper=ubd,mu=m,Sigma=v,dist="normal")$varcov
      #             S_star=MCmeanvarTMD(lower=lbd,upper=ubd,mu=m,Sigma=v,dist="normal")$EYY

      return(S_star)
    }

  }else{ # No censoring
    S_star=S_star_reorder
    return(S_star)
  }
}

eval_betascore=function(yc,x){
  ############################################################################################
  # input:    -yc      :a 1xp response vector of continous values: centered y_star
  #           -x       :a 1xd design matrix of covariates (if intercepts are considered, should have a col of 1s) #
  # output:   a vectorized dxp matrix as the individual score of beta taking the same dimension as beta.
  ############################################################################################
  return(as.vector(x%*%t(yc)))
}

combine=function(..., prefix='', sep='_') {
  combine.inner=function(lx, ...) {
    if (length(c(...)) > 0) {
      sapply(sapply(lx, function(x) paste(x, combine.inner(...), sep=sep)), c)
    } else {
      lx
    }
  }
  paste(prefix, combine.inner(...), sep='')
}

eval_obslogLik=function(y,c,x,pie,beta,sigma){
  ############################################################################################
  # input:    -y      :a nxp response matrix of continous values: subject to censoring.
  #           -c      :a nxp censorship matrix of 0,-1,1 indicating censoring directions.
  #           -x      :a nxd design matrix of covariates (if intercepts are considered, should have a col of 1s) #
  #           -pie    :a length G vector of mixing proportions which add up to 1.
  #           -beta   :a length G list of pxd coeficients matrices (loading matrices).
  #           -sigma  :a length G list of pxp varcov matrices.
  #
  # output:   a scalar of observed incomplete logLikelihood.
  ############################################################################################

  #determine the sample size and dimension
  if(dim(y)[1]==dim(c)[1] & dim(c)[1]==dim(x)[1]){
    N=dim(y)[1]
  } else {
    stop("sample sizes in y, c, x are different")
  }

  if(dim(y)[2]==dim(c)[2]){ #maybe consider sigma also?????
    P=dim(y)[2]
  } else {
    stop("feature dimensions in y, c are different")
  }


  if(length(beta)==length(sigma) & length(beta)==length(pie)){
    G=length(beta)
  } else {
    stop("pie, beta, sigma lengths are different")
  }


  lik=rep(0, N)
  for(g in 1:G){
    lik=lik+pie[g]*(dnorm(df$Y,as.matrix(df[c('X0','X1')])%*%beta[[g]],sigma[[g]])*(1-df$left_cenored)+
                      pnorm(df$Y,as.matrix(df[c('X0','X1')])%*%beta[[g]],sigma[[g]])*df$left_cenored)
  }
  LogLik=sum(log(lik))
}

eval_subdensity=function(Y,C,X,beta_hat,sigma_hat){

    N=dim(Y)[1]
    P=dim(Y)[2]
    D=dim(X)[2]

    if(length(beta_hat)==length(sigma_hat)){
      G=length(beta_hat)
    } else {
      stop("Intial beta, sigma lengths are different")
    }


    mu_hat=list()

    for(g in 1:G){
      mu_hat[[g]]=X%*%beta_hat[[g]]
    }

    ind_density=matrix(NA,nrow=N,ncol=G) #individual contribution to likelihood (NxK)
    for(g in 1:G){
        ## E-step: computing individual observation's contribution to the likelihood
        ind_density[,g]=mapply(eval_density,
                                          y=split(t(Y), rep(1:N, each = P)),
                                          c=split(t(C), rep(1:N, each = P)),
                                          m=split(t(mu_hat[[g]]), rep(1:N, each = P)),
                                          MoreArgs=list(v=sigma_hat[[g]]))
    }
    return(ind_density)
}



eval_class=function(p){
  return(which(p==max(p)))
}

#' True data generation
#'
#' @param Replicate the replicate number
#' @param n the number of observations
#' @param pie a bector of Mixing proportions
#' @param beta a list of Beta matrices
#' @param sigma a list of Sigma matrices
#'
#' @return a list of true data for simulation
#' @import mvtnorm
#' @export
#'
TrueDataGen=function(Replicate=30, n=1000,pie,beta,sigma){

  N=n

  G=length(pie) # Num of Clusters
  P=dim(beta[[1]])[2] # Dimension of Y
  D=dim(beta[[1]])[1] # Dimension of X (intercpt included)

  out=list()
  for(i in 1:Replicate){
    df_X=list()
    for(g in 1:G){
      df_X[[g]]=cbind(rep(1,pie[g]*N),do.call('cbind',lapply(rep(pie[g]*N,1),rnorm,0)))
    }


    mu=list()
    for(g in 1:G){
      mu[[g]]=df_X[[g]]%*%beta[[g]]
    }


    df_Y=list()
    for(g in 1:G){
      df_Y[[g]]=as.data.frame(mu[[g]]+mvtnorm::rmvnorm(pie[g]*N,mean=rep(0,P),sigma=sigma[[g]]))
      colnames(df_Y[[g]])=paste(rep('Y',P),1:P, sep = "", collapse = NULL)
      df_Y[[g]]$True_label=g
    }

    df_X=do.call('rbind',df_X)
    colnames(df_X)=paste(rep('X',D),1:D-1, sep = "", collapse = NULL)

    df_Y=do.call('rbind',df_Y)
    df_Labels=as.factor(df_Y$True_label)
    df_Y=as.matrix(df_Y[,1:P])


    df=list(df_Y,df_X,df_Labels)
    names(df)=c('Y','X','Labels')

    out[[i]]=df
  }

  return(out)

}


#' Generate the censored data for simulation
#'
#' @param True_Data example data generated by TrueDataGen
#' @param dl the censored limit
#'
#' @return a censored example data
#' @export
#'
CensDataGen=function(True_Data,dl){
  Replicate=length(True_Data)

  for(r in 1:Replicate){
    df_Y=True_Data[[r]]$Y
    N=dim(df_Y)[1]
    P=dim(df_Y)[2]

    censorID=matrix(rep(0,N*P),nrow=N,ncol=P)
    colnames(censorID)=paste(rep('C',P),1:P, sep = "", collapse = NULL)

    for(i in 1:N){
      for(d in 1:P){
        if(df_Y[i,d]<=dl[[d]][1]){
          df_Y[i,d]=dl[[d]][1]
          censorID[i,d]=-1
        }else{
          if(df_Y[i,d]>=dl[[d]][2]){
            df_Y[i,d]=dl[[d]][2]
            censorID[i,d]=1
          }
        }
      }
    }
    True_Data[[r]]$Y=df_Y
    True_Data[[r]]$censorID=censorID
  }

  return(True_Data)
}
