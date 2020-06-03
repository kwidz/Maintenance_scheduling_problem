using JuMP, Xpress

m = Model(()->Xpress.Optimizer(DEFAULTALG=2, PRESOLVE=0, logfile = "output.log"))
