from json import load, dump
from sys import argv
from minizinc import Model, Solver, Instance


# -----------------------------------------------------------------------------
# ----------------------------- Support Functions -----------------------------
# -----------------------------------------------------------------------------

# Converts a time in the format HHhMM to minutes
def get_minutes(time : str) -> int:
    return int(time[:2])*60+int(time[3:])

# Converts a time in the format HHhMM:HHhMM to [minutes,minutes]
def get_availability(time : str) -> list:
    return [int(time[:2])*60+int(time[3:5]), int(time[6:8])*60+int(time[9:])]

# Converts 0,1,2 to MedicalCenter,VehicleDepot,PatientLocation
def get_place_category(place : int) -> str:
    return "MedicalCenter" if place == 0 else "VehicleDepot" if place == 1 else "PatientLocation"

# Aggregates the output of the model into a list of trips by vehicle
# TODO: missing special cases (e.g. no returns, no forward activity, etc.)
def get_trips_by_vehicle(activityStart : list, activityEnd : list, activityVehicle: list) -> dict:
    global noVehicles, noRequests

    vehicleTripsAux = {i:list() for i in range(noVehicles)}

    # auxiliary tuple ~ (location, arrival, associatedPatient)
    vehicleTrips = {
        i: list() for i in range(noVehicles)
    }
    for patient, (actStart, actEnd, actVehicle) in enumerate(zip(activityStart, activityEnd, activityVehicle)):
        vehicleTripsAux[actVehicle[0]].append((requestData["requestStart"][patient], actStart[0], patient))
        vehicleTripsAux[actVehicle[0]].append((requestData["requestDestination"][patient], actEnd[0], patient))
        vehicleTripsAux[actVehicle[1]].append((requestData["requestDestination"][patient], actStart[1], patient))
        vehicleTripsAux[actVehicle[1]].append((requestData["requestReturn"][patient], actEnd[1], patient))
    
    onboardPatients = set()
    for vehicle in vehicleTripsAux:
        vehicleTripsAux[vehicle].sort(key=lambda x: x[1]) # sort by arrival time
        # trip tuple ~ (origin, destination, arrival, patients)
        (origin, arrival, patient) = vehicleTripsAux[vehicle].pop(0)
        vehicleTrips[vehicle].append((0, origin, arrival, set())) # first trip is from vehicle start to first patient
        onboardPatients.add(patient) # first patient gets onboard
        
        while vehicleTripsAux[vehicle]:
            (destination, arrival, patient) = vehicleTripsAux[vehicle].pop(0)
            vehicleTrips[vehicle].append((origin, destination, arrival, onboardPatients.copy()))
            if patient in onboardPatients: # if the activity is associated with the patient and they are onboard, they are now offboarding
                onboardPatients.remove(patient)
            else: # otherwise, they are now onboarding
                onboardPatients.add(patient)
            origin=destination # the next origin is the current destination
        
        vehicleTrips[vehicle].append((
            origin, 
            vehicleData["vehicleEnd"][vehicle], 
            arrival+ # last arrival time plus
            requestData["requestBoardingDuration"][patient]+ # the offboarding time of the last patient plus
            data["distMatrix"][destination][vehicleData["vehicleEnd"][vehicle]], # the time it takes to go from the current location to the vehicle depot
            onboardPatients.copy() # should be empty
            )) # the last trip is to the vehicle depot
        
    return vehicleTrips


# -----------------------------------------------------------------------------
# ----------------------------------- Setup -----------------------------------
# -----------------------------------------------------------------------------

input_name = argv[1]
output_name = argv[2]

input_file = open(input_name, 'r')
output_file = open(output_name, 'w')

data = load(input_file)

model = Model("./ptp.mzn")
solver = Solver.lookup("gecode")
instance = Instance(solver, model)


# -----------------------------------------------------------------------------
# ------------------------ Parse Input & Assign Values ------------------------
# -----------------------------------------------------------------------------
# JSON input format:
# {
#     "sameVehicleBackward": <bool>,
#     "maxWaitTime": <str>, # HHhMM
#     "places": [
#         {
#             "id": <int>,
#             "category": <int>
#         }
#     ],
#     "vehicles": [
#         {
#             "id": <int>,
#             "canTake": [<int>],
#             "start": <int>,
#             "end": <int>,
#             "capacity": <int>,
#             "availability": [<str>] # HHhMM:HHhMM
#         }
#     ],
#     "patients": [
#         {
#             "id": <int>,
#             "category": <int>,
#             "load": <int>,
#             "start": <int>,
#             "destination": <int>,
#             "end": <int>,
#             "rdvTime": <str>, # HHhMM
#             "rdvDuration": <str>, # HHhMM
#             "srvDuration": <str> # HHhMM
#         }
#     ]
# }

instance["sameVehicleBackward"] = data["sameVehicleBackward"]
instance["maxWaitTime"] = get_minutes(data["maxWaitTime"])

noPlaces = len(data["places"])
instance["noPlaces"] = noPlaces
instance["placeCategory"] = [get_place_category(place["category"]) for place in data["places"]]

noVehicles = len(data["vehicles"])
instance["noVehicles"] = noVehicles

vehicleData = dict(
    vehicleCanTake = [0]*noVehicles,
    vehicleStart = [0]*noVehicles,
    vehicleEnd = [0]*noVehicles,
    vehicleCapacity = [0]*noVehicles,
    vehicleAvailability = [[[0,0]]]*noVehicles,
)

noShifts = 0
noCategories = 0

for index, vehicle in enumerate(data["vehicles"]):
    vehicleData["vehicleCanTake"][index] = vehicle["canTake"]
    noCategories = max(noCategories, len(vehicle["canTake"]))
    vehicleData["vehicleStart"][index] = vehicle["start"]
    vehicleData["vehicleEnd"][index] = vehicle["end"]
    vehicleData["vehicleCapacity"][index] = vehicle["capacity"]
    vehicleData["vehicleAvailability"][index] = [get_availability(i) for i in vehicle["availability"]]
    noShifts = max(noShifts, len(vehicle["availability"]))

instance["noShifts"] = noShifts
instance["noCategories"] = noCategories

for key in vehicleData:
    instance[key] = vehicleData[key]

noRequests = len(data["patients"])
instance["noRequests"] = noRequests

requestData = dict(
    requestStart = [0]*noRequests,
    requestDestination = [0]*noRequests,
    requestReturn = [0]*noRequests,
    requestLoad = [0]*noRequests,
    requestServiceStartTime = [0]*noRequests,
    requestServiceDuration = [0]*noRequests,
    requestCategory = [0]*noRequests,
    requestBoardingDuration = [0]*noRequests
)

for index, patient in enumerate(data["patients"]):
    requestData["requestStart"][index] = patient["start"]
    requestData["requestDestination"][index] = patient["destination"]
    requestData["requestReturn"][index] = patient["end"]
    requestData["requestLoad"][index] = patient["load"]
    requestData["requestServiceStartTime"][index] = get_minutes(patient["rdvTime"])
    requestData["requestServiceDuration"][index] = get_minutes(patient["rdvDuration"])
    requestData["requestCategory"][index] = patient["category"]
    requestData["requestBoardingDuration"][index] = get_minutes(patient["srvDuration"])

for key in requestData:
    instance[key] = requestData[key]

instance["distMatrix"] = data["distMatrix"]


# -----------------------------------------------------------------------------
# --------------------------- Solve & Parse Output ----------------------------
# -----------------------------------------------------------------------------
# JSON output format:
# {
#     "requests": <int>,
#     "vehicles": [
#         {
#             "id": <int>,
#             "trips": [
#                 {
#                     "origin": <int>,
#                     "destination": <int>,
#                     "arrival": <str>, # HHhMM
#                     "patients": [<int>]
#                 }
#             ]
#         }
#     ]
# }


result = instance.solve()   

print(result)

# vehicleTrips = get_trips_by_vehicle(result["activityStart"], result["activityEnd"], result["activityVehicle"])

# dump(
#     {
#         "requests": result["noRequestsGranted"],
#         "vehicles": [
#             {
#                 "id": i,
#                 "trips": [
#                     {
#                         "origin": trip[0],
#                         "destination": trip[1],
#                         "arrival": f"{trip[2]//60}h{trip[2]%60:02d}",
#                         "patients": [trip[3]]
#                     }
#                     for trip in vehicleTrips[i]
#                 ]
#             } for i in range(noVehicles)
#         ]
#     },
#     fp=output_file
# )

