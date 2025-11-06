from threading import Thread
from threading import local
from queue import Queue
from QueueData import QueueData
from OSCFeedback import OSCFeedback
from FeedbackMessage import FeedbackMessage
from states.StopState import StopState
from states.ServoPoseState import ServoPoseState
from states.MoveJointsState import MoveJointsState
from states.RobotStateType import RobotStateType
from states.RobotState import RobotState
from states.TeachModeState import TeachModeState
from states.ServoJointsState import ServoJointsState
from states.RotationModeType import RotationModeType

import logging

import rtde_receive
import rtde_control

import sys
import math

import time


class RobotController(Thread):
    def __init__(self, dataQueue: Queue, driveRobot: bool, docker: bool = False):
        
        # --- counters for loop frequency ---
        self._loop_counter = 0
        self._last_time = time.time()

        self.stopRequest = False

        #prepare robot connection
        #self.robotIP = "127.0.0.1"
        self.robotIP = "192.168.188.29"
        self.readFreq = 500
        

        self.dataQueue = dataQueue
        self.driveRobot = driveRobot
        self.feedback = OSCFeedback()
        self.docker = docker
            
        #connect to the robot
        logging.info('Connecting to robot %s', self.robotIP)
        self.rtde_c = rtde_control.RTDEControlInterface(self.robotIP)
        self.rtde_r = rtde_receive.RTDEReceiveInterface(self.robotIP)
        
        #prepare runstates        
        self.stopState = StopState(RobotStateType.STOP, self.rtde_r, self.rtde_c, self.driveRobot)
        self.servoPoseState = ServoPoseState(RobotStateType.SERVOPOSE, self.rtde_r, self.rtde_c, self.driveRobot, self.docker)
        self.servoJointsState = ServoJointsState(RobotStateType.SERVOJOINTS, self.rtde_r, self.rtde_c, self.driveRobot)
        self.moveJointsState = MoveJointsState(RobotStateType.MOVEJOINTS, self.rtde_r, self.rtde_c, self.driveRobot)
        self.teachModeState = TeachModeState(RobotStateType.TEACHMODE, self.rtde_r, self.rtde_c, self.driveRobot)
        
        self.previousRunState = None
        self.runState = self.stopState

        logging.info("Connected!")        
        Thread.__init__(self)
        pass

    def __flushQueue(self):
        #drop all previously sent commands
        with self.dataQueue.mutex:
            self.dataQueue.queue.clear()
            self.dataQueue.all_tasks_done.notify_all()
            self.dataQueue.unfinished_tasks = 0


    def __fetchQueueData(self) -> dict:
        if self.dataQueue.empty():
            #logging.debug("Queue empty")            
            return {QueueData.EMPTYQUEUE: None}
        
        data = self.dataQueue.get()        
        logging.debug(f"Got new Queue Data {data}")
        self.dataQueue.task_done()

        #Match queue data to runstates - this seems unneccessary, but i want to keep runstates and queue data separate. This enables us to deal with other data than runstatenames later.
        queuedRunstate: RobotState

        match list(data.keys())[0]:
            case QueueData.SERVOPOSE:
                queuedRunstate = self.servoPoseState

            case QueueData.MOVEJOINTS:
                queuedRunstate = self.moveJointsState
            
            case QueueData.SERVOJOINTS:
                queuedRunstate = self.servoJointsState

            case QueueData.STOP:
                queuedRunstate = self.stopState
            
            case QueueData.TEACHMODE:
                queuedRunstate = self.teachModeState

            case _:
                pass

        #Make sure the data belongs to the current runstate, if not return
        if(self.runState.getStateType() != queuedRunstate.getStateType()):
            if(self.runState.statetype == RobotStateType.STOP):
                #we are in STOP and can switch to other states
                #we also know that the runstate desired is an actual runstate, so we can safely switch to another state
                self.changeState(queuedRunstate)
                logging.info("Changed runstate from %s to %s", self.previousRunState.getStateType(), self.runState.getStateType())
            
            elif(queuedRunstate.getStateType() == RobotStateType.STOP):
                logging.info("Received stop request - entering stop state")
                self.changeState(self.stopState)

            else:
                logging.warning("Data %s does not match current runstate %s", queuedRunstate.getStateType(), self.runState.getStateType())
                return       

        #Update the runstate
        match list(data.keys())[0]:
            case QueueData.SERVOPOSE:
                
                """early return when the transform matrix is malformed"""
                if(len(data[QueueData.SERVOPOSE]) < 6):
                    logging.warning("Transformmatrix malformed")
                    return

                """Reform this to a list matching std::vector<double> &x"""
                transformdata = []
                for i in range(6):                    
                    transformdata.append(float(data[QueueData.SERVOPOSE][i]))
                
                logging.debug(transformdata)
                
                rotationmode = 0
                if(len(data[QueueData.SERVOPOSE]) == 7):                    
                    rotationmode = int(data[QueueData.SERVOPOSE][6])

                    match rotationmode:
                        case 0:
                            logging.debug("RotationMode %s", rotationmode)
                            self.runState.setRobotPose(transformdata, RotationModeType.RxRyRz)                            
                        
                        case 1:
                            logging.debug("RotationMode %s", rotationmode)
                            self.runState.setRobotPose(transformdata, RotationModeType.RPY)
                            
                        case _:
                            logging.warning("Invalid rotation mode provided: %s", rotationmode)
                            self.runState.setRobotPose(transformdata, RotationModeType.RxRyRz)
                            return
                    
                
            
            case QueueData.MOVEJOINTS:
                if(len(data[QueueData.MOVEJOINTS]) != 8):
                    logging.warning("Movejoints values malformed")
                    return
                
                jointdata = []
                
                for val in data[QueueData.MOVEJOINTS][:6]:
                     jointdata.append(float(val))
                                      
                speed = float(data[QueueData.MOVEJOINTS][6])
                acceleration = float(data[QueueData.MOVEJOINTS][7])
                
                movejparams = {
                    "jointdata": jointdata,
                    "speed": speed,
                    "acceleration": acceleration
                }
                
                logging.debug(movejparams)
                self.runState.setJoints(movejparams["jointdata"], movejparams["speed"], movejparams["acceleration"])           

           
            case QueueData.SERVOJOINTS:
                if(len(data[QueueData.SERVOJOINTS]) != 6):
                    logging.warning("Servojoints values malformed")
                    return
            
                jointdata = []

                for val in data[QueueData.SERVOJOINTS]:
                    jointdata.append(float(val))

                servoJParams = {
                    "jointQ": jointdata
                }

                self.runState.setJoints(servoJParams["jointQ"])    

            case _:
                '''TODO: This warning is misunderstandable, as this warning is getting thrown
                also for all states which can't be updated such as stop and teachmode. Is it 
                really necessary? It is checked with the current runstate IMHO...'''
                #logging.warning("Unexpected data key: %s", list(data.keys())[0])

    def startRobotControl(self):
        #kick off thread
        self.start()

    def cancel(self):
        self.stopRequest = True    

    def run(self):

        logging.info("RobotWriteLoop started with state %s", self.runState)
        
        try:
            while self.stopRequest == False:

                #receive new data and update states                
                self.__fetchQueueData()                

                #run my runstate
                self.runState.run()
                
                # --- frequency counter ---
                self._loop_counter += 1
                now = time.time()
                if now - self._last_time >= 1.0:
                    print(f"Loop executed {self._loop_counter} times in the last second")
                    self._loop_counter = 0
                    self._last_time = now
                
            else:
                #Stop the Robot and return
                self.changeState(self.stopState)
                self.runState.run()
                return
               

        except KeyboardInterrupt:
            logging.info("Robot writer stopped by keyboard interrupt")
    
    def changeState(self, newState: RobotState):
        self.__flushQueue()
        self.previousRunState = self.runState
        self.runState.leave()
        self.runState = newState
        self.runState.enter()
    

        