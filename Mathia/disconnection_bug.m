imageNum = 3; % Number of images to take
expTime = 10; % The exposure time of the cameras

P = obs.unitCS('02'); % Create the main class
for i=1:4
    P.Slave{i}.Logging = true; % Enable logging for the slaves
end 

P.connect; % Initiate the connection to the cameras

pause (10)

% allow logging for SDK errors (in slaves) and save to stderror log files 
for i=1:4
    P.Camera{i}.classCommand('DebugOutput = true');
    P.Camera{i}.classCommand('DebugLogLevel = 3'); % define verbose level for SDK errors
    P.Camera{i}.classCommand('Verbose = 2'); % similar to the DebugLogLevel, but with internal commands
end
pause (10)

% check that all slaves are alive, and for each camera disable the display with ds9
for i=1:4
    fprintf('Slave %i - %s \n',i,P.Slave{i}.Status);
    % Clears the display, this is to avoid bugs when opening all 4 images
    % simultaneously.
    P.Camera{i}.classCommand('Display= []');
end

% Take (imageNum) images, with (expTime) exposure, with all 4 cameras
P.takeExposure([] ,expTime, imageNum);

pause (2)
% Disconnect immediately, without giving time for the exposure
P.disconnect;
P.CameraPower (:) = 0;
% This should make the slaves crash