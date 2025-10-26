# Physical Interfaces / Human–robot interaction
winter term 2025/2026

Technical University of Applied Sciences Augsburg, Prof. Andreas Muxel


# Simulation
## Docker
* install Docker Desktop https://docs.docker.com/desktop/
* start Docker Desktop

The following steps just needs to be done once, when you start simulation for the first time:
* on the bottom of Docker Desktop open ">_ Terminal"
* type in terminal
```
docker run --name ursim -it --network bridge -p 2222:2222 -p 29999:29999 -p 30001-30004:30001-30004 -p 5900:5900 universalrobots/ursim_e-series ROBOT_MODEL=UR5
```
Otherwise, if executed the next time:
* select "VNC Viewer" on the left side (view install instrucions below)
* no credentials needed
* select session and press "Connect"

## VNC Viewer Simulation
* open https://hub.docker.com/extensions/pgmystery/docker-extension-vnc
* select "Open in Docker Desktop" and install extension
* create a new session using the "+" on the topleft
* Give a "Session Name", for example "ursim"
* Connection-Type is "Docker Container"
* refresh the next field and look for "/ursim" and select it
* set VNC port to 5900
* select option "Stop Container after disconnect"
* press "Connect"
* power on virtual robot (very similar to real robot)
* when finished"Disconnect"


# Open Sound Control (OSC) interface / RTDE interface
## install Boost (Mac only)

* install Apple's Command Line Developer Tools with Terminal: 
```
xcode-select --install
```
* see next steps here: https://www.macports.org/install.php 
* run in Terminal:
```
sudo port install boost
```

## install Anaconda (environment managment Python and packages)
* download and install Anaconda here: https://www.anaconda.com/
* once Anaconda is installed, open it, create a new environment and call it "robot" (make sure you are using a python version that is supported by the ur-rtde package here: https://pypi.org/project/ur-rtde/ -> Python version 3.12 should work for Windows and Mac
* video tutorial Prof. Michael Kipp: https://www.youtube.com/watch?v=sDKVHmPsEEY&t=29s (just Anaconda needed, skip Tensorflow, Seaborn & Jupiter Noteook)
* start environment with play button and select "Open Terminal"
* type the following commands in the Terminal (might take some time to install, esprecially on Mac):
```
pip install ur_rtde
```
```
pip install python-osc
```

## Visual Studio Code & OSC Python scripts
* download code repository, https://github.com/HybridThingsLab/course-robotics/archive/refs/heads/2025.zip and unzip
* launch VS Code from Anaconda at "Home" with "robot" selected in the top of the Home tab
* add folder "course-robotics-2025" to your workspace with "File/Add Folder to Workspace"
* save workspace
* find scripts to read and write data to robot viaOpen Sound Control (OSC) in subfolder of folder "/Python"
* view Folder in "Explorer" (icon documents left)
* in the "Python/RTDE_OSC_read" folder in VSCode navigate to -> src\config.json and change the “ip” to the IP Address of the robot (simulation or real robot) (burger menue top right "About")
* in the "Python/RTDE_OSC_write" folder in VSCode navigate to -> src\RobotController.py and change the “ip” to your IP Address of the robot (simulation or real robot)
* open two terminal windows in VSCode side-by-side by using the split option in the terminal (icon window left from trash can)
* in one terminal window change the directory to RTDE_OSC_read\src by typing "cd " and drag and drop "src" folder to terminal
* run the script by typing
```
python main.py
```
* in the other terminal window change the directory to RTDE_OSC_write\src by typing "cd " and drag and drop "src" folder to terminal
* if you run the real robot type in the terminal
```
python main.py --driverobot
```
* if you run robot as a simulation with Docker type in the terminal
```
python main.py --driverobot --docker
```
* you should get an message "INFO:root:connected!"
* open one example provided in the repository (p.ex. "TouchDesigner/02_RobotController/robotController.toe")
* to stop a Python script press "ctrl+c" in the terminal
* to restart use UP or DOWN key to recall last prompts and press RETURN

# TouchDesigner, Processing, P5.js
* any tool with an OSC interface can be used to control the robot
* see also code examples provided in this repository
* downloads:
    * TouchDesigner, https://derivative.ca/product/touchdesigner-non-commercial/77
    * Processing, https://processing.org/download
    * p5js, https://p5js.org/download/
    * ...
