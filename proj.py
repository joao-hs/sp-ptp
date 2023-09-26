from json import load, dump
from sys import argv
from minizinc import Model, Solver, Instance

input_name = argv[1]
output_name = argv[2]

input_file = open(input_name, 'r')
output_file = open(output_name, 'w')

data = load(input_file)

model = Model("./ptp.mzn")
solver = Solver.lookup("gecode")
instance = Instance(solver, model)

result = instance.solve()
