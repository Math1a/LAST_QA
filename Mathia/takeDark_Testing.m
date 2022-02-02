%This script is used to test the takeDarks function
%
%Variables: 
%loops: Number of times to run the main loop
%imageNum: Number of images to take per camera, per loop
%imageDiff: The difference of images between each loop
%expTime: The exposure time of the cameras


%% Variable Setup

loops = 5; % Number of times to run the main loop
imageNum = 9; % Number of images to take per camera, per loop
imageDiff = -2; % The difference in exposure time between each loop (in seconds)
expTime = 20; % The exposure time of the cameras
totalImages = 0;

existingImg = [0,0,0,0];
for i = 1:4
    if i <= 2
        command = "ssh last03.local ls -t /last03/data1/archive/LAST.00.01.0" + i + "/new";
    else
        command = "ls -t /last04/data" + (i-2) + "/archive/LAST.00.01.0" + i + "/new";
    end
    [result,fileList] = system(command); % The directory where the images are saved
    if result == 0
        fileList = splitlines(fileList);
        for s = 1 : length(fileList)
            if contains(fileList{s}, "Image")
                existingImg(i) = existingImg(i) + 1;
            end
        end
    end
end

% Create the diary file
filename = strcat("~/Mathia/Logs/Mathia_Log_Darks"+string(datestr(now,'dd-mm-yyyy_HH:MM:SS'))+".txt");
diary(filename)  % Open a new log file
fprintf("\n New run %s \n Loops = %d \n Image number = %d \n Image difference each loop = %d \n Exposure time = %f \n", datestr(now), loops, imageNum, imageDiff, expTime)

%% Main Setup

P = obs.unitCS('02'); % Create the main class (with simulated mount)

for i=1:4
    P.Slave{i}.Logging = true; % Enable logging for the slaves
end

P.connect; % Initiate the connection to the cameras

pause (5)

% Allow logging for SDK errors (in slaves) and save to stderror log files
for i=1:4
    P.Camera{i}.classCommand('DebugOutput = true');
    P.Camera{i}.classCommand('DebugLogLevel = 3'); % define verbose level for SDK errors
    P.Camera{i}.classCommand('Verbose = 2'); % similar to the DebugLogLevel, but with internal commands
end
pause (10)

% Check that all slaves are alive, and for each camera disable the display with ds9
for i=1:4
    fprintf('Slave %i - %s \n',i,P.Slave{i}.Status)
    % Clears the display, this is to avoid bugs when opening all 4 images
    % simultaneously.
    P.Camera{i}.classCommand('Display= []');
end
fprintf('\n\n')

pause(10) % Pause before the main loop, this is to let the mount move to its home position

% Check camera status for sucsessful connection
for i = 1:4
    if isempty(P.Camera{i}.classCommand('CameraName'))
        fprintf("\n Unexpected camera status at camera %i. Retrying. \n", i)
        P.Slave{i}.disconnect;
        P.CameraPower(i) = 0;
        pause (10)
        P.CameraPower(i) = 1;
        P.connectSlave;
        
        if isempty(P.Camera{i}.classCommand('CameraName'))
            error("Something might be wrong with camera %d, check it and try again.", i)
        end
    end
    
    fprintf("Camera %d connected sucsessfuly. \n", i)
    
end

fprintf('\n Setup complete \n\n')

pause(5)

%% Main Loop

for lapse = 1:loops
    
    % Check if all cameras are ready to take a picture
    for i = 1:4
        P.readyToExpose(i, true, (expTime * (imageNum - imageDiff * loops + 1)) + 6);
        if P.readyToExpose(i)
            fprintf ("Camera %d ready to expose \n", i)
        else
            fprintf ("\n Camera %d took too much time to respond, restarting...\n Please note that the last image might be lost. \n", i)
            P.Slave{i}.disconnect
            pause(10)
            P.connectSlave(i);
            P.readyToExpose(i, true);
        end
    end
    
    fprintf ("\n New round at %s Taking %d images per camera with exposure time of %f. \n\n", datestr(now),imageNum ,expTime)
    tic % Start the timer
    % Take (imageNum) images, with (expTime) exposure, with all 4 cameras
    P.takeDarks([] ,expTime, imageNum);
    timeout = (expTime * imageNum + (imageNum * 3) + 10);
    pause(timeout)
    P.readyToExpose(1, true, (expTime * 2)); % Wait for cameras to take images
    for i = 2:4
        P.readyToExpose(i, true, 10); % Wait for cameras to take images
    end
    toc() % Count how much time it took to take the images
    fprintf("\n Image capture finished for round %d \n", lapse)
    
    % Calculate the total number of images taken by each camera
    totalImages = totalImages + imageNum;
    imageNum = imageNum + imageDiff;
    % Wait for images to save and focusers to move
    pause (10)
end

%% Post proccesing

% Check again if all cameras are ready, before shutting down
for i = 1:4
    P.readyToExpose(i, true, (expTime * (imageNum + 1)) + 6);
    if P.readyToExpose(i)
        fprintf ("\n Camera %d finished normally \n", i)
    else
        fprintf ("\n Camera %d took too much time to respond, restarting...\n Please note that the last image might be lost. \n", i)
        P.Slave{i}.disconnect
        pause(5)
        P.connectSlave(i)
        P.readyToExpose(i, true)
    end
end

% Check how many imaes are present in the images folder
newImg = [0,0,0,0];
for i = 1:4
    if i <= 2
        command = "ssh last03.local ls -t /last03/data1/archive/LAST.00.01.0" + i + "/new";
    else
        command = "ls -t /last04/data" + (i-2) + "/archive/LAST.00.01.0" + i + "/new";
    end
    [result,fileList] = system(command); % The directory where the images are saved
    if result == 0
        fileList = splitlines(fileList);
        for s = 1 : length(fileList)
            if contains(fileList{s}, "Image")
                newImg(i) = newImg(i) + 1;
            end
        end
    end
end

newImg = newImg - existingImg
% Comapre number of images taken and number of images saved
fprintf ("\n \n %d images should have been taken, %d out of them succesfully saved. \n \n", totalImages * 4, sum(newImg))

% Calculate the time interval between the image capture time
% Create the variables in which the times are going to be stored in

fprintf ("\n\n              Session complete at , shutting down.\n")
P.shutdown;
pause (10)
diary off;




