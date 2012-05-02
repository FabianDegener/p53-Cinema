function [] = immunofluorescenceCP(CPoutput,varargin)
% [] = processManualSegTrackViaImageJ()
% Input:
% CPoutput = the path to a Cell Profiler *.mat file.
%
% Output:
%
%
% Description:
% I have been liking Cell Profiler for quantifying immunofluorescence data
% recently. This file will analyze the output from Cell Profiler.
%
% Other Notes:
% 
p = inputParser;
p.addRequired('CPoutput', @(x)ischar(x));
p.addParamValue('infoName','Nuclei',@(x)ischar(x));
p.parse(CPoutput, varargin{:});

CP = open(CPoutput);

%Plot some histograms
nucleiArea = CP.handles.Measurements.Nuclei.AreaShape_Area;
nucleiMeanIntensityYFP = CP.handles.Measurements.Nuclei.Intensity_MeanIntensity_YFP;
nucleiMeanIntensityCy5 = CP.handles.Measurements.Nuclei.Intensity_MeanIntensity_Cy5;
nucleiMeanIntensityDAPI = CP.handles.Measurements.Nuclei.Intensity_MeanIntensity_DAPI;
nucleiSolidity = CP.handles.Measurements.Nuclei.AreaShape_Solidity;
nucleiCompactness = CP.handles.Measurements.Nuclei.AreaShape_Compactness;
nucleiFormFactor = CP.handles.Measurements.Nuclei.AreaShape_FormFactor;
nucleiX = CP.handles.Measurements.Nuclei.AreaShape_Center_Y;
nucleiY = CP.handles.Measurements.Nuclei.AreaShape_Center_X;
DAPIfilenames = CP.handles.Measurements.Image.FileName_DAPI;

numberoflifeunits = 0;
for i = 1:length(nucleiArea)
    numberoflifeunits = numberoflifeunits + numel(nucleiArea{i});
end

nucleiArea_array = linearizeContentsOfCell(nucleiArea,numberoflifeunits);
nucleiMeanIntensityYFP_array = linearizeContentsOfCell(nucleiMeanIntensityYFP,numberoflifeunits);
nucleiMeanIntensityCy5_array = linearizeContentsOfCell(nucleiMeanIntensityCy5,numberoflifeunits);
nucleiMeanIntensityDAPI_array = linearizeContentsOfCell(nucleiMeanIntensityDAPI,numberoflifeunits);
nucleiSolidity_array = linearizeContentsOfCell(nucleiSolidity,numberoflifeunits);
nucleiCompactness_array = linearizeContentsOfCell(nucleiCompactness,numberoflifeunits);
nucleiFormFactor_array = linearizeContentsOfCell(nucleiFormFactor,numberoflifeunits);

%----- Create a new folder to hold corrected images -----
tempfoldername=regexp(CPoutput,'(?<=\\)[\w ]*','match'); %Prepare to create a new folder to place background subtracted stacks
tempdrive = regexp(CPoutput,'[a-zA-Z]:','match');
tempfoldername{end} = 'figures';
imagepath=fullfile(tempdrive{1},tempfoldername{:});
mkdir(imagepath);
cd(imagepath)


%Filtering the dataset
%Area is used to filter out objects that are too small to be nuclei. Use a
%log-normal distribution to eliminate small outliers. Senescent cells are
%known to have large nuclei, so these outliers should not be eliminated.
[afarray,mu,sigma] = areafilter(nucleiArea_array);
myplothistarea(nucleiArea_array,'nucleiArea',afarray,mu,sigma);




%Clumped cells and senescent cells have similar areas. To distinguish
%between clumped cells and senescent cells a combined measure is used:
%compactness, form-factor, and solidity. These 3 measures give a sense of
%how circular, or round, is a nuclei. Senescent cells tend to have very
%large round nuclei.
%form-factor gives a measure of how circular an object is by comparing the
%equivalent area of circle to the perimenter. This measure 
%should be less than 1. It is best fit to a distribution when the measures
%are abs(1-x), where x is the form-factor measurement. Since 0<x<1 it might
%be worth looking at the -log(x) distribution.
[fffarray,paramhat] = formfactorfilter(nucleiFormFactor_array);
myplothistformfactor(nucleiFormFactor_array,'nucleiFormFactor',fffarray,paramhat)
%Solidity detects the presence of furrows or deviations from a smooth curve
%by comparing the convex hull area to the object area. Clumped cells can be
%thought of a overlapping ellipses that would produce object furrows. It is
%a measure that is 0<x<1 and has a similar distribution to the form-factor.
sfarray = formfactorfilter(nucleiSolidity_array);
%Compactness gives a second way to measure furrows or spikes. Compactness
%should be greater than 1. Taking the log of this data will move the
%smallest value of the disribution to 0 and make it easier to compare
%outliers, which might have extreme values since this statistic is a ratio.
cfarray = formfactorfilter(nucleiCompactness_array);


myplothist(nucleiSolidity_array,'nucleiSolidity',sfarray)
myplothist(nucleiCompactness_array,'nucleiCompactness',cfarray)
myplothist(nucleiMeanIntensityDAPI_array.*nucleiArea_array,'TotalNucleiDAPI')
myplothist(nucleiMeanIntensityYFP_array.*nucleiArea_array,'TotalNucleiYFP')
myplothist(nucleiMeanIntensityCy5_array.*nucleiArea_array,'TotalNucleiCy5')

end

function [y] = linearizeContentsOfCell(x,numolu)
y = zeros(1,numolu);
counter = 1;
for i = 1:length(x)
    temp = numel(x{i});
    y(counter:temp+counter-1) = x{i};
    counter = counter+temp;
end
end

function [] = myplothist(x,filename,vline)
h=figure ( 'visible', 'off', 'position', [10, 10, 672, 512] );
ax=axes('parent',h);
hist(ax,x,100);
title(filename);
hold on
yL = get(ax,'YLim');
line([vline vline],yL,'Color','r');
saveas (ax, filename, 'pdf' );
close(h);
end

function [] = myplothistarea(x,filename,vline,mu,sigma)
h=figure ( 'visible', 'off', 'position', [10, 10, 672, 512] );
ax=axes('parent',h);
[y,x2] = hist(x,100);
h2 = bar(ax,x2,y/(sum(y)*(x2(2)-x2(1))),'hist');
set(h2,'FaceColor',[0 0.5 1],'EdgeColor',[0 0 1]);
title(filename);
hold on
y2 = lognpdf(x2,mu,sigma);
plot(ax,x2,y2,'Color','black','LineWidth',1.5)
yL = get(ax,'YLim');
line([vline vline],yL,'Color','r','LineWidth',1.5);
hold off
saveas (ax, filename, 'pdf' );
close(h);
end

function [] = myplothistformfactor(x,filename,vline,paramhat)
h=figure ( 'visible', 'off', 'position', [10, 10, 672, 512] );
ax=axes('parent',h);
[y,x2] = hist(x,100);
h2 = bar(ax,x2,y/(sum(y)*(x2(2)-x2(1))),'hist');
set(h2,'FaceColor',[0 0.5 1],'EdgeColor',[0 0 1]);
title(filename);
hold on
y2 = lognpdf(x2,mu,sigma);
plot(ax,x2,y2,'Color','black','LineWidth',1.5)
yL = get(ax,'YLim');
line([vline vline],yL,'Color','r','LineWidth',1.5);
hold off
saveas (ax, filename, 'pdf' );
close(h);
end

function [y,meanlogx,sigmalogx] = areafilter(x)
L = length(x);
%assume area is distributed as a log-normal distribution
logx = log(x);
%assume there are outliers. We want to ignore these outliers while fitting
%the normal distribution, so we discard the bottom and top 10%.
logx = sort(logx);
logx = logx(round(L*.1):round(L*.9));
%From this trimmed set we have to bootstrap the tails of the distribution.
bootset = randn(L,1);
bootset = sort(bootset);
%We must estimate the variance of the distribution from the trimmed set.
%This variance must be scaled by the variance of a zero mean, unit variance
%normal distribution trimmed the same way. The z-score for a 10% tail is
%1.2815.
%The variance for this trimmed distribution can be found numerically using
%MATLAB. x = randn(1e6,1);x = sort(x);x = x(round(length(x)*.1):round(length(x)*.9));var(x)
%he variance equals 0.4377
varlogx = var(logx)/.4377;
sigmalogx = sqrt(varlogx);
meanlogx = mean(logx);
%The bootset is scaled by the mean and variance of the sample data
bootset = bootset*sigmalogx+meanlogx;
%The bootstraped tails are added to the trimmed distribution.
bootmin = bootset(bootset<min(logx));
bootmax = bootset(bootset>max(logx));
newdist = [bootmin',logx,bootmax'];
%The new distribution is scaled to zero mean and unit variance
newdistmean = mean(newdist);
newdistvar = var(newdist);
newdist = (newdist-newdistmean)/sqrt(newdistvar);
%The goodness of fit to a normal distribution is tested by the
%kolmogorov-smirnoff test.
goodfitbool = kstest(newdist);
if goodfitbool
    disp('The distribution of nuclei areas is not log-normal. Check to see if it is bi-modal.')
end
%Use 3 sigma below the mean as the cutoff for nucleus size
y = exp(meanlogx - 3*sqrt(varlogx));
end

function [y,paramhat] = formfactorfilter(x)
L = length(x);
logx = -log(x);
%fit with Weibull distribution. First all values must be positive.
temp = logx(logx>0);
logx(logx<=0) = min(temp);
paramhat = wblfit(logx);
[~,x2] = hist(logx,100);
y2 = wblcdf(x2,paramhat(1),paramhat(2));
%Find the CDF of the data for the kstest
logx = sort(logx);
x3 = logx(1:floor(L/99):L);
x3 = x3(1:100);
p = ((1:100)-0.5)' ./ 100;
[xcdf,ycdf] = stairs(x3,p);
end

function [y] = compactnessfilter(x)
L = length(x);
logx = log(x);

y = logx;
end

function [y] = solidity(x)
L = length(x);
logx = -log(x);

y = logx;
end