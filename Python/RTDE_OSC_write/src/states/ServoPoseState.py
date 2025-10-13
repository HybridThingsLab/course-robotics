from states.RobotState import RobotState
from FeedbackMessage import FeedbackMessage
import states.RobotStateType
import logging
from .RotationModeType import RotationModeType
from util.RPYTools import RPYtoVec

import rtde_receive
import rtde_control

import time

class ServoPoseState(RobotState):
    def __init__(self, statetype: states.RobotStateType, rtde_r: rtde_receive.RTDEReceiveInterface, rtde_c: rtde_control.RTDEControlInterface, driveRobot:bool, docker: bool = False) -> None:
        super().__init__(statetype, rtde_r, rtde_c, driveRobot)
        self.velocity = 0.5
        self.acceleration = 0.5
        self.dt = 1.0/500  # 2ms
        self.lookahead_time = 0.2
        self.gain = 100

        self.robotPose = None
        
        self.docker = docker 

    def setRobotPose(self, newRobotPose, rotationMode):
        if rotationMode == RotationModeType.RPY:
            #convert to Eulers to Euclidians
            euclidians = RPYtoVec(newRobotPose[3], newRobotPose[4], newRobotPose[5])
            newRobotPose[3] = euclidians[0]
            newRobotPose[4] = euclidians[1]
            newRobotPose[5] = euclidians[2]

        self.robotPose = newRobotPose 

    def enter(self):
        return super().enter()        

    def run(self):
        
        t_start = self.rtde_c.initPeriod()
        
        if(not self.docker):
            logging.debug("IK solution: %r", self.rtde_c.getInverseKinematicsHasSolution(self.robotPose))

        # check whether pose is wihtin safety limits
        if (not self.rtde_c.isPoseWithinSafetyLimits(self.robotPose)):
            self.feedback.send(FeedbackMessage.POSESAFETYVIOLATION)
            return

        # check whether IK is reacheable      
        if (not self.rtde_c.getInverseKinematicsHasSolution(self.robotPose)):
            self.feedback.send(FeedbackMessage.IKNOSOLUTION)
            return      
                
        # convert pose to joint q
        pose_joint_q = self.rtde_c.getInverseKinematics(self.robotPose)      
        
        # check whether pose is wihtin safety limits
        if (not self.rtde_c.isJointsWithinSafetyLimits(pose_joint_q)):
            self.feedback.send(FeedbackMessage.JOINTSAFETYVIOLATION)
            return

        # all good - proceed with robot control
        self.rtde_c.servoJ(pose_joint_q, self.velocity, self.acceleration, self.dt, self.lookahead_time, self.gain)  
        
        # check if simulation run in docker
        if(self.docker):
            time.sleep(0.01) # quick&dirty fix for Docker?!     
            
        self.rtde_c.waitPeriod(t_start)

