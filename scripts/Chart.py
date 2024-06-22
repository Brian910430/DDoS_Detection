import matplotlib.pyplot as plt
import sys

with open('logs/forChart.txt', 'r') as file:
    data = file.readlines()

ip_data = {}

init_min = int(sys.argv[1])
init_sec = int(sys.argv[2])

for line in data:
    values = line.split()
    ip = values[0]
    minute = int(values[1])
    second = int(values[2])
    estimate = float(values[3])

    time = 60 * (minute - init_min) + second - init_sec
    
    if ip not in ip_data:
        ip_data[ip] = {'time': [], 'estimate': []}
    
    ip_data[ip]['time'].append(time)
    ip_data[ip]['estimate'].append(estimate)

for item in ip_data:
    ip_data[item]['time'].insert(0, 0)
    ip_data[item]['estimate'].insert(0, 0)

for ip, values in ip_data.items():
    plt.plot(values['time'], values['estimate'], label=ip)

plt.title('Estimate Values Over Time')
plt.xlabel('Time')
plt.ylabel('Estimate Value')
plt.legend()
plt.show()
