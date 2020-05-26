
using JuMP
using GLPK
using LinearAlgebra
function benders()
    # definition du problème maitre
    #exemple infaisable
    c1=[1;6;5;7]                    # n1 x 1
    c2=[9;3;0;2;3]                  # n2 x 1
    b=[-3;-4;1;4;5]                   # m  x 1
    A1=[
        0 -2 3 2;
        -5 0 -3 1;
        1 0 4 -2;
        0 -3 4 -1;
        -5 -4 3 0
        ]
     A2=[
        3 4 2 0 -5;
        0 2 3 -2 1;
        2 0 1 -3 -5;
        -5 3 -2 -3 0;
        -2 3 -1 2 -4
        ]
#exemple faisable
#        c1=[-2;-8]
#        c2=[-1; -7]
#        b=[-1;-2]
#        A1=[
#        4 -7;
#        -5 -3
#        ]
#        A2=[
#        5 -1;
#        -3 -2
#        ]



    dimentionX=length(c1)
    dimentionU=length(c2)

    M=1000

    masterProblem = Model(optimizer_with_attributes(GLPK.Optimizer, "tm_lim" => 60000, "msg_lev" => GLPK.OFF))

    # définition des variables
    @variable(masterProblem, 0<= x[1:dimentionX]<= 1e6  , Int)
    @variable(masterProblem, t<=1e6)

    # definition de la fonction objective
    @objective(masterProblem, Max, t)
    iC=1 # compteur d'itérations

    print(masterProblem)
    # on fait la décomposition de benders en une étape
    while(true)
        iC
        println("\n-----------------------")
        println("itération numero : ", iC)
        println("-----------------------\n")
        println("Le problème maitre est :")
        print(masterProblem)
        optimize!(masterProblem)
        status_MasterProblem = termination_status(masterProblem)
        println(status_MasterProblem)


        if status_MasterProblem == MOI.INFEASIBLE
            println("Le problème n'est pas faisable")
            break
        end

        if status_MasterProblem == MOI.DUAL_INFEASIBLE
            fmCurrent = M
            xCurrent=M*ones(dimentionX)
        end


        if status_MasterProblem == MOI.OPTIMAL
            fmCurrent = value(t)
            xCurrent=Float64[]
            for i in 1:dimentionX
                push!(xCurrent,value(x[i]))
            end
        end

        println("le statut du problème maitre est : ", status_MasterProblem,
        "\navec fmCurrent = ", fmCurrent,
        "\nxCurrent = ", xCurrent)

        #definition du sous problème
        subProblem = Model(optimizer_with_attributes(GLPK.Optimizer, "tm_lim" => 60000, "msg_lev" => GLPK.OFF))

        cSub=b-A1*xCurrent

        @variable(subProblem, u[1:dimentionU]>=0)


        @constraint(subProblem, constrRefSubProblem[j=1:size(A2,2)],sum(A2[i,j]*u[i] for i in 1:size(A2,1))>=c2[j])



        @objective(subProblem, Min, dot(c1, xCurrent) + sum(cSub[i]*u[i] for i in 1:dimentionU))

        print("\nLe sous problème actuel est : \n", subProblem)
        optimize!(subProblem)
        status_SubProblem = termination_status(subProblem)

        fsxCurrent = objective_value(subProblem)

        uCurrent = Float64[]

        for i in 1:dimentionU
            push!(uCurrent, value(u[i]))
        end

        γ=dot(b,uCurrent)

        println("le statut du sous problème est ", status_SubProblem,
        "\navec fsxCurrent= ", fsxCurrent,
        "\net fmCurrent= ", fmCurrent)

        if status_SubProblem == MOI.OPTIMAL &&  fsxCurrent == fmCurrent # we are done
            println("\n################################################")
            println("solution optimale au probleme original trouvée")
            println("la valeur de l'objectif est : ", fmCurrent)
            println("la valeur de x est  ", xCurrent)
            println("la valeur de v est  ", "dual(constrRefSubProblem")
            println("################################################\n")
            break
        end

        if status_SubProblem == MOI.OPTIMAL && fsxCurrent < fmCurrent
            println("\non peut encore ajouter une contrainte au problème maitre")
            cv= A1'*uCurrent - c1
            @constraint(masterProblem, t+sum(cv[i]*x[i] for i in 1:dimentionX) <= γ )
            println("t + ", cv, "ᵀ x <= ", γ)
        end

        if status_SubProblem == MOI.DUAL_INFEASIBLE
            println("\non peut encore ajouter une contrainte au problème maitre")
            ce = A1'*uCurrent
            @constraint(masterProblem, sum(ce[i]*x[i], i in 1:dimentionX) <= γ)
            println(ce, "ᵀ x <= ", γ)
        end

        iC=iC+1

    end
end
benders()
