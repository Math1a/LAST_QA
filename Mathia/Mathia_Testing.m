%% Variable Setup

loops = 100; % Number of times to run the main loop
imageNum = 5; % Number of images to take
expTime = 20; % The exposure time of the cameras
focusFrequency = 20; % The amout of loops between each focusLoop

if (hour(now) > 10)
    filetime = datestr(now,'yyyy/mm/dd');
else
    filetime = datestr(now - days(1), 'yyyy/mm/dd');
end

[result,fileList] = system("ssh last03.local ls -t /last03/data1/archive/LAST/"+ filetime +"/raw"); % The directory where the images are saved
existinglast03 = 0;
if result == 0
    fileList = splitlines(fileList);
    for s = 1 : length(fileList)
        if contains(fileList{s}, "_sci_")
            existinglast03 = existinglast03 + 1;
        end
    end
else
    existinglast03 = 0;
end

[result,fileList] = system("ls -t /last04/data1/archive/LAST/"+ filetime +"/raw"); % The directory where the images are saved
existinglast04 = 0;
if result == 0
    fileList = splitlines(fileList);
    for s = 1 : length(fileList)
        if contains(fileList{s}, "_sci_")
            existinglast04 = existinglast04 + 1;
        end
    end   
end

% Create the diary file
filename = strcat("~/Mathia/Logs/Mathia_Log_"+string(datestr(now,'dd-mm-yyyy_HH:MM:SS'))+".txt");
diary(filename)  % Open a new log file 
fprintf("\n New run %s \n Taking %d images per camera, %d at a time, with an exposure time of %d. \n\n", datestr(now), loops * imageNum, imageNum, expTime) % fprintf is used instead of disp to better control the text

%% Main Setup

P = obs.unitCS('02+'); % Create the main class

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

% Check for mount status
switch P.Mount.Status
    case 'disabled'
        fprintf('\n Mount connected successfully \n')
        P.Mount.home;
    case 'unknown' 
        error('The mount did not connect successfully')
        
    otherwise
        fprintf('\n Unexpected mount status... Check mount or try reconnecting \n')
end

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
               fprintf("\n Something might be wrong with camera %d, check it and try again. \n", i)
               break
           end
       end
       
       % Take the focuser to its max position
       %P.Focuser{i}.classCommand('Pos = %d', P.Focuser{i}.classCommand('Limits(2)'));
       
       fprintf("Camera %d connected sucsessfuly. \n", i)
    end
    
% Do a focusLoop before starting the main loop
fprintf("\n\n Focus time! \n\n")
P.focusLoop;
    
fprintf('\n Setup complete \n\n')

pause(5)

%% Main Loop

for lapse = 1:loops

    % Genertate random position, based on the mount's limits
    AZPos = 360 * rand;
    ALTPos = (rand * 75) + 15;
    % Move to the generated position
    fprintf('\n Moving mount to position: Azimuth = %f, Altitude = %f \n', AZPos, ALTPos)
    P.Mount.goTo(AZPos, ALTPos, 'azalt');
    
    % Do a P.focusLoop every (focusFrequency) lapses
    if mod(lapse, focusFrequency) == 0
        fprintf("\n\n Focus time! \n\n")
        P.focusLoop;
    end
    
    % Check if all cameras are ready to take a picture
    for i = 1:4
        P.readyToExpose(i, true, (expTime * (imageNum + 1)) + 6);
        if P.readyToExpose(i)
            fprintf ("Camera %d ready to expose \n", i)
        else
            fprintf ("\n Camera %d took too much time to respond, restarting...\n Please note that the last image might be lost. \n", i)
            P.Slave{i}.disconnect
            pause(10)
            P.connectSlave(i)
            P.readyToExpose(i, true)
        end
    end
    
    fprintf ("\n New round at %s Taking images... \n", datestr(now))
    tic % Start the timer
    % Take (imageNum) images, with (expTime) exposure, with all 4 cameras
    P.takeExposure([] ,expTime, imageNum);
    P.readyToExpose(1, true, (expTime * (imageNum + 2)) + 10); % Wait for cameras to take images
    for i = 2:4
        P.readyToExpose(i, true, 10); % Wait for cameras to take images
    end
    toc() % Count how much time it took to take the images
    fprintf("\n Image capture finished for round %d \n", lapse)
    
    % Change the focus for the next round by (focusChange)
    %fprintf("Moving focusers... \n")
    %for i = 1:4  
    %    P.Focuser{i}.classCommand('Pos = (P.Focuser{%d}.Pos - %d)', i, focusChange);
    %end
    
    % Wait for images to save and focusers to move
    pause (10)
end

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

% Calculate the total number of images taken by each camera
totalImages = loops * imageNum; 

% Check how many imaes are present in the images folder
[result,last03] = system("ssh last03.local ls -t /last03/data1/archive/LAST/"+ filetime +"/raw"); % The directory where the images are saved
filenum03 = 0;
file03 = splitlines(last03);
for s = 1 : length(file03)
    if contains(file03{s}, "_sci_")
        filenum03 = filenum03 + 1;
    end
end

[result,last04] = system("ls -t /last04/data1/archive/LAST/"+ filetime +"/raw"); % The directory where the images are saved
filenum04 = 0;
file04 = splitlines(last04);
for s = 1 : length(file04)
    if contains(file04{s}, "_sci_")
        filenum04 = filenum04 + 1;
    end
end

newlast03 = filenum03 - existinglast03;
newlast04 = filenum04 - existinglast04; 
% Comapre number of images taken and number of images saved
fprintf ("\n \n %d images should have been taken, %d out of them sucsessfuly saved. \n \n", totalImages * 4, newlast03 + newlast04)

% Calculate the time interval between the image capture time
% Create the variables in which the times are going to be stored in
times01 = (1 : (imageNum * loops)) * 0;
times02 = (1 : (imageNum * loops)) * 0;
times03 = (1 : (imageNum * loops)) * 0;
times04 = (1 : (imageNum * loops)) * 0;

index01 = 1;
index02 = 1;
for i = 1 : (imageNum * loops * 2)
    if contains(file03{i}, ".01_")
        times01(index01) = datenum(file03{i}(15 : 33),'yyyymmdd.HHMMSS.fff');
        index01 = index01 + 1;
    elseif contains(file03{i}, ".02_")
        times02(index02) = datenum(file03{i}(15 : 33),'yyyymmdd.HHMMSS.fff');
        index02 = index02 + 1;
    end
end

index03 = 1;
index04 = 1;
for i = 1 : (imageNum * loops * 2)
    if contains(file04{i}, ".03_")
        times03(index03) = datenum(file04{i}(15 : 33),'yyyymmdd.HHMMSS.fff');
        index03 = index03 + 1;
    elseif contains(file04{i}, ".04_")
        times04(index04) = datenum(file04{i}(15 : 33),'yyyymmdd.HHMMSS.fff');
        index04 = index04 + 1;
    end
end

timesAll = [times01; times02; times03; times04]; % Combine all the image capture time into one large matrix
delays = zeros(3, (imageNum * loops) - 1); % Create an empty array containing the delay times

% Calculate the delays between each image to the next
for row = 1 : imageNum * loops
    for col = 1:3
        delays(col, row) = timesAll(col + 1, row) - timesAll(col, row);
    end
end
delays = delays * 86400000 % Convert delays to milliseconds

fprintf("\n Average delay between each camera: %f ms \n Standard deviation: %f ms \n", mean(delays, 'all'), std(delays, 1, 'all'))

fprintf ("\n\n              Session complete at , shutting down.\n")
P.shutdown;
pause (10)
clear classes;
diary off;




