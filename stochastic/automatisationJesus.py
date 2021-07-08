import os
home_dir = os.system("cd ~/Doctorat/Maintenance_scheduling_problem/stochastic")
for i in range(1,25):
    os.system("julia problemDefinitionArguments.jl "+str(i))
    
