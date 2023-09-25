# Search and Planning - Patient Transportation Problem as a CSP

**Requirements**:
- `python` (version 3.10.12)
- `pip`
- `minizinc` (version 2.7.6) to use the IDE

## Setup

- Create a virtual environment
```shell
python -m venv .venv
```

- Active it
```shell
source .venv/bin/activate
```

- Install requirements
```shell
pip install -r requirements.txt
```

- Run
```shell
python proj.py <input-json> <output-json>
```

## Test

- Use `test.sh` script, refer to `--help` documentation
```shell
./test.sh --help
```

## Solution

### Non-decision variables table
| Entity  | Parameter        | Meaning                                                           | Domain                                                            |
| ------- | ---------------- | ----------------------------------------------------------------- | ----------------------------------------------------------------- |
| Request | $\text{start}_i$ | Starting place of the patient linked to request $i$               | 0..1440                                                           |
| "       | $\text{dest}_i$  | Place where the care is delivered for the patient of request $i$  | 0..1440                                                           |
| "       | $\text{ret}_i$   | Return place of the patient linked to request $i$                 | 0..$\#\text{places}$                                              |
| "       | $l_i$            | Number of vehicle places taken by the patient of request $i$      | 0..$\text{max-vehicle-capacity}$                                  |
| "       | $u_i$            | Time at which the health care service begins for request $i$      | 0..1440                                                           |
| "       | $d_i$            | Time needed to deliver the care for the patient of request $i$    | 0..1440                                                           |
| "       | $p_i$            | Maximum travel time of the patient linked to request $i$          | 0..1440                                                           |
| "       | $c_i$            | Category of patient of request $i$ (wheelchair, without, etc.)    | 0..$\#\text{categories}$                                          |
| "       | $w_i$            | Maximum amount of time that a patient can wait **(cumulative)**                | 0..1440                                                           |
| "       | $\text{bk}_i$    | Amount of time associated with embarking/disembarking             | 0..1440                                                           |
| Vehicle | $k_j$            | Capacity of vehicle $j$ (*i.e.* the number of places available) **(cumulative)**   | 1..$\text{max-vehicle-capacity}$                                  |
| "       | $C_j$            | Set of patient categories that vehicle $j$ can take               | array\[0..\#$\text{categories}$\] of 0..1                         |
| "       | $\text{shift}_j$ | In what shift is currently vehicle $j$ in                         | 0..$\text{max-number-of-shifts}$                                  |
| "       | $S_j$            | Set of pairs shifts's starting and ending times                   | array\[0..$\text{max-number-of-shifts}$, 0..1\] of 0..1440        |
| "       | $L_j$            | Set of pairs of locations to be at the start and end of the shift | array\[0..$\text{max-number-of-shifts}$, 0..1\] of 0..$\#\text{places}$ |


