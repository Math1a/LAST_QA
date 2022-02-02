%% Variable Setup
imageNum = 3; % Number of images to take at once
expTime = 6; % The exposure time of the cameras
focusChange = 200; % The focuser motor position
f = dir("/last04/data1/archive/LAST/"+datestr(now,'yyyy/mm/dd')+"/raw"); % The directory where the images are saved
existingImg = (length(f) - 2); % The amount of images that were in the directory before the run

% Create the diary file
filename = strcat("~/Mathia/Logs/Mathia_Log_Video_Mode"+string(datestr(now,'dd-mm-yyyy_HH:MM:SS'))+".txt");
diary(filename)  % open a new log file 
fprintf("\n New run %s \n Taking %d images in total, %d at a time, with an exposure time of %d. \n\n", datestr(now), 4 * imageNum, imageNum, expTime); % fprintf is used instead of disp to better control the text

%% Main Setup

P = obs.unitCS('02+'); % Create the main class
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

    
    % Check camera status for sucsessful connection
    for i = 1:4
       if isempty(P.Camera{i}.classCommand('CameraName'))
           fprintf("\n Unexpected camera status at camera %i. Retrying. \n", i);
           P.Slave{i}.disconnect;
           P.CameraPower(i) = 0;
           pause (10)
           P.CameraPower(i) = 1;
           P.connectSlave;
           
           if isempty(P.Camera{i}.classCommand('CameraName'))
               fprintf("\n Something might be wrong with camera %d, check it and try again. \n", i);
               break
           end
       end
       
       % Take the focuser to its max position
       P.Focuser{i}.classCommand('Pos = %d', P.Focuser{i}.classCommand('Limits(2)'));
       
       fprintf("\n Camera %d connected sucsessfuly.", i);
    end
    
 % Wait for the focusers to move
 pause (15)

%% Main Loop

for ncamera = 1:4

    % Check if all cameras are ready to take a picture
    P.readyToExpose(ncamera, true, (expTime * (imageNum + 1)) + 6);
    if P.readyToExpose(ncamera)
        fprintf ("\n Camera %d ready to expose \n", ncamera)
    else
        fprintf ("\n Camera %d took too much time to respond, restarting...\n Please note that the last image might be lost. \n", ncamera)
        P.Slave{ncamera}.disconnect
        pause(5)
        P.connectSlave(ncamera)
        P.readyToExpose(ncamera, true)
    end
    
    fprintf ("\n\n New round at %s Taking images... \n", datestr(now))
    tic % Start the timer
    % Take (imageNum) images, with (expTime) exposure, with ncamera
    P.takeExposure(ncamera ,expTime, imageNum);
    toc() % Count how much time it took to take the image
    fprintf("\n Image capture finished for round %d", ncamera);
    
    fprintf("\n Moving focusers...")
    % Change the focus for the next round by (focusChange)
     P.Focuser{ncamera}.classCommand('Pos = (P.Focuser{%d}.Pos - %d)', ncamera, focusChange);
    
end

% Check again if all cameras are ready, before shutting down
for i = 1:4
    P.readyToExpose(i, true, (expTime * (imageNum + 1)) + 6);
    if P.readyToExpose(i)
        fprintf ("\n Camera %d ready to expose \n", i)
    else
        fprintf ("\n Camera %d took too much time to respond, restarting...\n Please note that the last image might be lost. \n", i)
        P.Slave{i}.disconnect
        pause(5)
        P.connectSlave(i)
        P.readyToExpose(i, true)
    end
end
% Calculate the total number of images that the camera should have taken
totalImages = 4 * imageNum / 2;
% Check how many imaes are present in the images folder
f = dir("/last04/data1/archive/LAST/"+datestr(now,'yyyy/mm/dd')+"/raw");
newImg = (length(f) - 2) - existingImg; 
% Comapre number of images taken and number of images saved
fprintf ("\n \n %d images should have been taken by cameras 3 and 4, %d out of them sucsessfuly saved. \n \n", totalImages, newImg)


disp ("Session complete, shutting down.")
P.disconnect;
P.CameraPower (:) = 0;
diary off;




