import json
from sys import argv

def write_array1d(name, data, file):
    file.write(f"{name} = array1d(0..{len(data) - 1}, [")
    file.write(", ".join(map(str, data)))
    file.write("]);\n")

def write_array2d(name, data, file):
    rows = len(data)
    cols = len(data[0])
    file.write(f"{name} = array2d(0..{rows - 1}, 0..{cols - 1}, [|")
    for row in data:
        file.write(" ")
        file.write(", ".join(map(str.lower, map(str, row))))
        file.write(", |")
    file.write("]);\n")

def vehicle_availability(data, file):
    rows = len(data)
    cols = len(data[0])
    file.write(f"vehicleAvailability = array2d(0..{rows - 1}, ShiftPos, [|")
    for row in data:
        file.write(" ")
        file.write(", ".join(map(str.lower, map(str, row))))
        file.write(", |")
    file.write("]);\n")

def translate_json_to_minizinc(json_data, output_file):
    with open(output_file, "w") as minizinc_file:
        for key, value in json_data.items():
            if isinstance(value, list):
                if isinstance(value[0], list):
                    if key == "vehicleAvailability":
                        vehicle_availability(value, minizinc_file)
                    else:
                        write_array2d(key, value, minizinc_file)
                else:
                    write_array1d(key, value, minizinc_file)
            elif isinstance(value, bool):
                minizinc_file.write(f"{key} = {str(value).lower()};\n")
            else:
                minizinc_file.write(f"{key} = {value};\n")

if __name__ == "__main__":
    json_file = argv[1]  # Replace with your JSON file path
    minizinc_file = argv[2]  # Replace with the desired MiniZinc output file

    with open(json_file, "r") as file:
        json_data = json.load(file)

    translate_json_to_minizinc(json_data, minizinc_file)

