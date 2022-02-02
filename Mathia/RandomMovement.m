iterations = 10;
timeout = 15;

X = inst.XerxesMount;
X.connect

for k = (1:iterations)
    X.goTo(rand * 360, rand * 180 - 90, 'azalt')
    pause(timeout)
    
    if ~ (X.Status == ("idle"))
        disp('Invalid status, Returning Home')
        X.abort
        X.home
    end
end

X.disconnect
X.park