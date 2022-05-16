%% definitions
lapses = 20 ; % number of lapses = iterations of the main loop 
N = 1; % Number of images per camera 
expTime = 10; % exposure time

%% initiate session - logging and status of cameras 
% create log file of the current date run
filename = strcat("~/Mathia/Mathia_Log_"+string(datestr(now,'dd-mm-yyyy_HH:MM:SS'))+".txt");
diary(filename)  % open a new log file 
fprintf("\n new run %s \n\n", datestr(now)); % fprintf is used instead of disp to better control the text

P = obs.unitCS("-1");

% enable log files for slaves 
for i=1:2; P.Slave{i}.Logging = true; end 
% connect slaves 
P.connect

% allow logging for SDK errors (in slaves) and save to stderror log files 
for i=1:2
    P.Camera{i}.classCommand('DebugOutput = true');
    P.Camera{i}.classCommand('DebugLogLevel = 5'); % define verbose level for SDK errors
    P.Camera{i}.classCommand('Verbose = 2'); % similar to the DebugLogLevel, but with internal commands
end

% check that all slaves are alive, and for each camera disable the display with ds9
for i=1:2
    fprintf('Slave %i - %s \n',i,P.Slave{i}.Status);
    % Clears the display, this is to avoid bugs when opening all 4 images
    % simultaneously.
    P.Camera{i}.classCommand('Display= []');
end


%% main 
for lapse=1:lapses 
    fprintf("\n\n starting to take images. %s \n\n", datestr(now));
    % define path of images:
    path = strcat('/last03w/data1/archive/LAST/'+string(datestr(date,'yyyy/mm/dd'))+'/raw');
    % print cameras status (temp and cooling power):
    tempe = [];
    cooling = [];
    for i=1:2
        if ~isempty(P.Camera{i}.classCommand('Temperature')) && ~isempty(P.Camera{i}.classCommand('CoolingPower'))
            fprintf('camera %i: temp = %.1f, cooling power = %.1f%% \n',...
                i, P.Camera{i}.classCommand('Temperature'),P.Camera{i}.classCommand('CoolingPower'));
            cooling(end+1) = P.Camera{i}.classCommand('CoolingPower');
            tempe(end+1)= P.Camera{i}.classCommand('Temperature');
        end
    end
    
    % take N images with all 4 cameras
    P.takeExposure([],expTime,N);
    
    TakeExp(lapse) = 1; % is this a variable? unsure of its use
    time0 = tic; % start a stopwatch timer
    maximum = 60; % time in seconds "allowed" for taking images before forcing stop
    NumTaken = [];
    for i=1:2
        if isempty(P.Camera{i}.classCommand('ProgressiveFrame')) % check if slave is alive (checks how many images were last taken)
            continue % why use continue when you can use ~?
        else
            while P.Camera{i}.classCommand('ProgressiveFrame')<N
                pause(0.2)
                if toc(time0) >= maximum % Timeout
                    fprintf("camera %i delayed",i);
                    break;
                end
            end
        end
    end
    
    disp(' ');
    toc(time0)
    TimeToTake(lapse) = toc(time0);
    
    %print amount of images taken by each camera
    for i=1:2
        if isempty(P.Camera{i}.classCommand('ProgressiveFrame'))
            continue
        else fprintf("\nCamera %i took %i/%i images of %.2f exp time",i,...
                      P.Camera{i}.classCommand('ProgressiveFrame'),N, expTime)
            NumTaken(end+1)=P.Camera{i}.classCommand('ProgressiveFrame');
        end
    end
    
    timelast = [];
    for i=1:2
        fprintf("\ncamera %i took last image at = %s", i,...
            datestr(P.Camera{i}.classCommand('TimeStartLastImage'),'HH:MM:SS.FFF'))
        %timelast(i) = P.Camera{i}.classCommand('TimeStartLastImage');
    end
    
    Timedelta(lapse) = str2double(datestr(max(timelast)-min(timelast),'SS.FFF'));
    
    imageSum = sum(NumTaken); % number of images taken
    imageslist = dir(path); % list of files in path
    fprintf("\n%i out of %i images were saved: \n", imageSum, N*2);
    
    % check which images were saved and when:
    %start = length(imageslist)-imageSum +1;
    %for i=start:length(imageslist); disp(imageslist(i).name); end
end


disp("pause for 10 seconds");
pause(10)

% lot of timerouts with slaves: checking status before disconnecting

for i=1:2
    fprintf('Slave %i - %s \n',i,P.Slave{i}.Status);
    P.Camera{i}.classCommand('Display= []');
end

% finish session-
%P.disconnect
%clear P ;

diary off;
% % if a Slave timed out :
% P.Slave{1}.classCommand('disconnect');
% %or
% P.Slave{1}.classCommand('kill');
