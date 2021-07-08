using JuMP, Xpress

Xpress.Optimizer(OUTPUTLOG = 1)
model = Model(()->Xpress.Optimizer(DEFAULTALG=2, PRESOLVE=1, logfile = "output2.log"))
@variable(model, test[i in 1:1000; i in [1,3,5]]<=10)
@objective(model, Max, test[1])
JuMP.optimize!(model)
