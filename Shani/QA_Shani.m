
%% definitions - and empty arrays to fill with statistics (only once !)
lapses = 30; % number of lapses = iterations of the main loop 
N = 20; % Number of images per camera 
expTime = 15; % exposure time
TimeToTake = zeros(lapses,1); % array to save the elapsed time after taking images
Temp = zeros(lapses,1); 
Tempstd = zeros(lapses,1);
CoolingPower = zeros(lapses,1);
Coolingstd = zeros(lapses,1);
SlaveTimeOut = zeros(lapses,1);
Count = zeros(lapses,1); % array to use as index for plots (adds one count for each iteration) 
Timedelta = zeros(lapses,1); % array to save the time delta of saving images (between slaves)

%% initiate session - logging and status of cameras 
% create log file of the current date run
filename = strcat('Rachel_Log_'+string(datestr(now,'dd-mm-yyyy_HH:MM:SS')));
diary(filename)  % open a new log file 
fprintf("\n new run %s \n\n", datestr(now));

P = obs.unitCS("02");

% enable log files for slaves 
for i=1:4; P.Slave{i}.Logging = true; end 
% connect slaves 
P.connect
pause(60)

% allow logging for SDK errors (in slaves) and save to stderror log files 
for i=1:4
P.Camera{i}.classCommand('DebugOutput = true'); 
P.Camera{i}.classCommand('DebugLogLevel = 7'); % define verbsoe level for SDK errors
P.Camera{i}.classCommand('Verbose = 2'); 
end
% check that all slaves are alive, and for each camera disable the display with ds9
pause(10)
for i=1:4
    fprintf('Slave %i - %s \n',i,P.Slave{i}.Status);
    P.Camera{i}.classCommand('Display= []');
end


%% main 
lapse = 1;
while lapse<=lapses
Count(lapse) = lapse;
fprintf("\n\n starting to take images. %s \n\n", datestr(now));
% define path of images:
path = strcat('/last04/data1/archive/LAST/'+string(datestr(date,'yyyy/mm/dd'))+'/raw');
% print cameras status (temp and cooling power):
tempe = [];
cooling = [];
for i=1:4
    if isempty(P.Camera{i}.classCommand('Temperature')) | isempty(P.Camera{i}.classCommand('CoolingPower')) 
        continue
    else; fprintf('camera %i: temp = %.1f, cooling power = %.1f%% \n',...
        i, P.Camera{i}.classCommand('Temperature'),P.Camera{i}.classCommand('CoolingPower')); 
    cooling(end+1) = P.Camera{i}.classCommand('CoolingPower');
    tempe(end+1)= P.Camera{i}.classCommand('Temperature');
    end
end
    
CoolingPower(lapse)= mean(cooling);
Coolingstd(lapse)=std(cooling);
Temp(lapse) = mean(tempe);
Tempstd(lapse) = std(tempe); 

P.takeExposure([],expTime,N);

TakeExp(lapse) = 1;
time0 = tic;
maximum = 400; % time in seconds "allowed" for taking images before forcing stop 
NumTaken = [];
for i=1:4
    if isempty(P.Camera{i}.classCommand('ProgressiveFrame'))
        continue
    else
        while P.Camera{i}.classCommand('ProgressiveFrame')<N
        pause(0.2)
        if toc(time0) >= maximum
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
for i=1:4
    if isempty(P.Camera{i}.classCommand('ProgressiveFrame')) ==1 
        continue
    else fprintf("\nCamera %i took %i/%i images of %.2f exp time",i,P.Camera{i}.classCommand('ProgressiveFrame'),N, expTime)
    NumTaken(end+1)=P.Camera{i}.classCommand('ProgressiveFrame'); 
    end 
end

timelast = [];
for i=1:4
    fprintf("\ncamera %i took last image at = %s", i,...
        datestr(P.Camera{i}.classCommand('TimeStartLastImage'),'HH:MM:SS.FFF'))
    %timelast(i) = P.Camera{i}.classCommand('TimeStartLastImage');
end 

Timedelta(lapse) = str2double(datestr(max(timelast)-min(timelast),'SS.FFF'));

fprintf('\n\nPixel mean check:\n')
disp(P.Slave{1}.Messenger.query('mean(P.Camera{1}.LastImage(:))'));
disp(P.Slave{2}.Messenger.query('mean(P.Camera{2}.LastImage(:))'));
disp(P.Slave{3}.Messenger.query('mean(P.Camera{3}.LastImage(:))'));
disp(P.Slave{4}.Messenger.query('mean(P.Camera{4}.LastImage(:))'));

imageSum = sum(NumTaken); % number of images taken
imageslist = dir(path); % list of files in path
fprintf("\n%i out of %i images were saved: \n", imageSum, N*4);

% check which images were saved and when:
%start = length(imageslist)-imageSum +1; 
%for i=start:length(imageslist); disp(imageslist(i).name); end

lapse = lapse+1
end


disp("pause for 10 seconds");
pause(10)


% finish session-
P.CameraPower(:)=0;  % turn cameras off
%P.CameraPower(:)=1;   % turn cameras on
P.disconnect
%clear P ;


% statistics 
fprintf("\nout of %i runs (exp time = %i, N=%i), \naverage saving time = %.2fs, \naverage temp = %.2f, \naverage cooling power = %.2f%% \nTime delta between images(s) = %f \n",...
    lapse,expTime, N,mean(nonzeros(TimeToTake)), mean(nonzeros(Temp)), mean(nonzeros(CoolingPower)), mean(nonzeros(Timedelta)));
fig1 = figure;
scatter(nonzeros(Count), nonzeros(Temp),25,'filled'); xlabel('Count','fontsize',12);ylabel('Temp')
saveas(fig1,strcat('Rachel_Temp_'+string(datestr(now,'dd-mm-yyyy hh:MM'))+'.jpeg'));
fig2 = figure;
scatter(nonzeros(Count),nonzeros(CoolingPower), 25,'filled');xlabel('Count', 'fontsize',12);ylabel('Cooling power','fontsize',14)
saveas(fig2, strcat('Rachel_Cooling_Power_'+string(datestr(now)))+'.jpeg')

T = table(Temp,Tempstd,CoolingPower,Coolingstd, TimeToTake,Timedelta);
writetable(T,strcat('Rachel_statistics_'+string(datestr(now))+'.csv'))


diary off;
% % if a Slave timed out : 
% P.Slave{1}.classCommand('disconnect');
% %or
% P.Slave{1}.classCommand('kill');

%% gradually worm cams to ~room temp before switching off 
for i=1:4
    fprintf("\n camera %i, temperature = %.1f",i, P.Camera{i}.classCommand('Temperature'));
    P.Camera{i}.classCommand('Temperature = 5');
    pause(25)
    fprintf("\n camera %i, temperature = %.1f",i, P.Camera{i}.classCommand('Temperature'));
    P.Camera{i}.classCommand('Temperature = 10');
    pause(25)
    fprintf("\n camera %i, temperature = %.1f",i, P.Camera{i}.classCommand('Temperature'));
    P.Camera{i}.classCommand('Temperature = 15');
    pause(25)
    fprintf("\nfinished warming camera %.1f. new temperature = %.2f",...
        i, P.Camera{i}.classCommand('Temperature'));
end 

%% try to cause disconnection bug
P.disconnect
pause(15)
for i=1:4; P.Slave{i}.Logging = true; end 
P.connect
pause(60)

%P.CameraPower(:)=0;  % turn cameras off
% enable log files
pause(10)

for i=1:4
    fprintf('camera %i: temp = %.1f, cooling power = %.1f%% \n',...
        i, P.Camera{i}.classCommand('Temperature'),P.Camera{i}.classCommand('CoolingPower'));
end 

for i=1:4
    P.Camera{i}.classCommand('Display= "ds9"');
end

P.takeExposure([],5,1);
pause(10)

for i=1:4
    fprintf("\n Camera %i Number of images taken = %i, status = %s",...
        i,P.Camera{i}.classCommand('ProgressiveFrame'),P.Camera{1}.classCommand('CamStatus'));
end 

disp(P.Slave{1}.Messenger.query('mean(P.Camera{1}.LastImage(:))'));
disp(P.Slave{2}.Messenger.query('mean(P.Camera{2}.LastImage(:))'));
disp(P.Slave{3}.Messenger.query('mean(P.Camera{3}.LastImage(:))'));
disp(P.Slave{4}.Messenger.query('mean(P.Camera{4}.LastImage(:))'));

for i=1:4
    fprintf("\ncamera %i took image at = %s", i,...
        datestr(P.Camera{i}.classCommand('TimeStartLastImage'),'HH:MM:SS.FFF'))
end 
%% try to cause cameras to crash by switching modes
t = now;
datename = string(datetime(t,'ConvertFrom','datenum'));
filename = strcat('Rachel_Log_'+datename);
diary(filename) 
options = [1,5];
lapse = 1;
delta = [];
expo = [];
expTime = 1;
while lapse<=lapses
    expo(lapse) = expTime;
    N = 1;
    fprintf("Take %i images",N)
    Count(lapse) = lapse;
    fprintf("\n\n starting to take images. %s \n\n", datestr(now));
    
    P.takeExposure([],expTime,N);
    TakeExp(lapse) = 1;
    time0 = tic;
    maximum = 400; % time in seconds "allowed" for taking images before forcing stop 
    NumTaken = [];
    pause(expTime+5)
    
%print amount of images taken by each camera 
    for i=1:4
        if isempty(P.Camera{i}.classCommand('ProgressiveFrame')) ==1 
            continue
        else fprintf("\nCamera %i took %i/%i images of %.2f exp time",i,P.Camera{i}.classCommand('ProgressiveFrame'),N, expTime)
            NumTaken(end+1)=P.Camera{i}.classCommand('ProgressiveFrame'); 
        end 
    end
disp(' ');
toc(time0)
delta(lapse) = toc(time0);
lapse = lapse+1
expTime = expTime +1;

disp("pause for 10 seconds");
pause(10)
end

fig1 = figure;
scatter(expo, delta,25,'filled'); xlabel('Exposure','fontsize',12);ylabel('Delta time')
saveas(fig1,'/home/last04/ocs/Rachel_exposure_delta.jpeg');








