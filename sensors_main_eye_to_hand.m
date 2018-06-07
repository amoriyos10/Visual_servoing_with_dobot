% Finds the pose of a camera fixed in the world with respect to the base of 
% the robot given the known location of a checkerboard with respect to the 
% base of the robot.

clear;
close all;

addpath('../class');
addpath('../utilities');

global dobot;
global tftree;
dobot = Dobot('dobot', []); 
tftree = rostf;


%% Joint subscriber
jointSub = rossubscriber('/dobot_magician/state', 'dobot_magician/State', @convertJointAngleToTfCallback);

%% Cam to checkerboard
markerSub = rossubscriber('/ar_pose_marker','ar_track_alvar_msgs/AlvarMarkers');
msg = receive(markerSub);
t_cam_CB = [msg.Markers.Pose.Pose.Position.X; ...
            msg.Markers.Pose.Pose.Position.Y; ...
            msg.Markers.Pose.Pose.Position.Z];
R_cam_CB = quat2rotm([msg.Markers.Pose.Pose.Orientation.W, ...
                      msg.Markers.Pose.Pose.Orientation.X, ...
                      msg.Markers.Pose.Pose.Orientation.Y, ...
                      msg.Markers.Pose.Pose.Orientation.Z]);
T_cam_CB = rt2tr(R_cam_CB, t_cam_CB);

%% Base to end effector
tftree.AvailableFrames;
waitForTransform(tftree, 'world', 'dobot_end', 10);
T_B_EE_msg = getTransform(tftree, 'world', 'dobot_end');
t_B_EE = [T_B_EE_msg.Transform.Translation.X; ...
             T_B_EE_msg.Transform.Translation.Y; ...
             T_B_EE_msg.Transform.Translation.Z];
R_B_EE = quat2rotm([T_B_EE_msg.Transform.Rotation.W, ...
                    T_B_EE_msg.Transform.Rotation.X, ...
                    T_B_EE_msg.Transform.Rotation.Y, ...
                    T_B_EE_msg.Transform.Rotation.Z]);
T_B_EE = rt2tr(R_B_EE, t_B_EE);


%% Constant inputs
q = receive(jointSub);
eul1 = [pi-q.JointAngles(3) -pi/2 0];
T_EE_CB = rt2tr(eul2rotm(eul1, 'zyx'), [0.055994 0 0]');

        
%% Calculate output
T_B_cam = T_B_EE * T_EE_CB * invTform(T_cam_CB)

%%
close all
figure;
trplot(eye(4),'length',0.5);
hold on
trplot(T_B_cam,'color',[0.5 0.5 0.5],'length',0.5);

% Callback which converts joint angles into a TF tree. This requires
% knowledge of the robot being used. Here we use a dobot, however, it can
% be modified to use any robot by changing the forward kinematics.
function convertJointAngleToTfCallback(src, msg)
    global dobot;
    global tftree;
    
%     disp('Received');
    
    q = msg.JointAngles(1:3);
    joint_poses = dobot.getRelativeJointPoses(q);
    joint_names = {'dobot_base', 'dobot_joint_1', 'dobot_joint_2', ...
                   'dobot_joint_3', 'dobot_end'};
                  
    tfStampedMsg = rosmessage('geometry_msgs/TransformStamped');
    tfStampedMsg.Header.Stamp = rostime('now');
    tfStampedMsg.Transform.Rotation.W = 1;
    tfStampedMsg.ChildFrameId = joint_names{1};
    tfStampedMsg.Header.FrameId = 'world';
    sendTransform(tftree, tfStampedMsg);
            
    for i=1:size(joint_poses,3)
        tfStampedMsg = rosmessage('geometry_msgs/TransformStamped');
        tfStampedMsg.ChildFrameId = joint_names{i+1};
        tfStampedMsg.Header.FrameId = joint_names{i};

        tfStampedMsg.Transform.Translation.X = joint_poses(1,4,i);
        tfStampedMsg.Transform.Translation.Y = joint_poses(2,4,i);
        tfStampedMsg.Transform.Translation.Z = joint_poses(3,4,i);
        
        r = joint_poses(1:3,1:3,i);
        quatrot = rotm2quat(r);
        tfStampedMsg.Transform.Rotation.W = quatrot(1);
        tfStampedMsg.Transform.Rotation.X = quatrot(2);
        tfStampedMsg.Transform.Rotation.Y = quatrot(3);
        tfStampedMsg.Transform.Rotation.Z = quatrot(4);
        tfStampedMsg.Header.Stamp = rostime('now');
        
        sendTransform(tftree, tfStampedMsg);
    end
end
