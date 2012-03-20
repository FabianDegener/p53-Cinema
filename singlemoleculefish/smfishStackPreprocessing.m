function [] = smfishStackPreprocessing(stackpath,varargin)
%noise reduction by matched filtering with a guassian kernel
%create gaussian filter that approximates 3D PSF of the microscope.
%Distance units are in micrometers.
%----- Set Parameters -----
flourescentChannel = 'Cy5'; %What channel had the FISH probes?
objective = 60; %as in 60x
NA = 1.4; %typical of 60x oil immersion objections
rindex = 1.51; %typical refractive index of oil
camerapixellength = 6.45; %Both cameras in the Lahav have pixel dimensions of 6.45 x 6.45 um.
zstepsize = 0.25; %User defined with z-stack is obtained
wavelength = .67; %Cy5 probe wavelength approximately 670 nanometers
%----- Parse varargin -----
%'flatfieldpath' = 'path\2\files'
%'subtractbackground' = true
p = inputParser;
p.addRequired('stackpath', @(x)ischar(x));
p.addParamValue('flatfieldpath', '', @(x)ischar(x));
p.addParamValue('subtractbackground', false, @(x)islogical(x));
p.parse(stackpath, varargin{:});
%----- flatfield correction for each z-slice -----
if ~isempty(p.Results.flatfieldpath)
    flatfieldcorrection(stackpath,p.Results.flatfieldpath)
    tempfoldername=regexp(stackpath,'(?<=\\)[\w ]*','match'); %Prepare to create a new folder to place background subtracted stacks
    tempfoldername=[tempfoldername{end},'_ff'];
    stackpath=[stackpath,'\..\',tempfoldername];
end
%----- read the contents of the input folder -----
disp(['working in ', stackpath]); %Sanity Check
dirCon_stack = dir(stackpath);
%----- Create a new folder to hold corrected images -----
tempfoldername=regexp(stackpath,'(?<=\\)[\w ]*','match'); %Prepare to create a new folder to place background subtracted stacks
tempfoldername=[tempfoldername{end},'_smFISH'];
smfishstackpath=[stackpath,'\..\',tempfoldername];
mkdir(smfishstackpath);
cd(smfishstackpath)
smfishstackpath=pwd;
%process only the stacks that contain single molecule FISH
stacknames=importStackNames(dirCon_stack,flourescentChannel);
stacknames2=stacknames; %I apologize for the really confusing file naming system.
%This is part of a bug. This file expects the input filename to be of a
%certain format. The following for-loop partially ensures the file names
%are in that format.
for i=1:length(stacknames)
    Name_temp = regexprep(stacknames(i),'\s',''); %Remove all not(alphabetic, numeric, or underscore) characters
    Name_temp = regexprep(Name_temp,'tocamera','','ignorecase'); %remove 'tocamera' if present b/c it is not informative
    Name_temp = regexprep(Name_temp,'camera','','ignorecase'); %remove 'camera' if present b/c it is not informative
    stacknames2(i) = Name_temp;
end

for bigInd = 1:length(stacknames)
    %----- Load the image file -----
    IM = loadZstack([stackpath '\' stacknames{bigInd}]);
    %----- background subtraction for each z-slice -----
    %I've heard that 3D deconvolution using an iterative blind-maximum-likehood
    %algorithm is very effective at removing out of focus light from each
    %z-slice. I played around with the AutoQuant software package at the NIC.
    %AutoQuant has this deconvolution algorithm and can batch process a whole
    %folder of files. The results were quite nice. However, the deconvolution
    %process is time consuming: it takes about 20 minutes for a 1344x1024x50
    %TIFF file and requires scheduling time at the NIC and using a computer at
    %the NIC for the processing. Perhaps later I can incorporate deconv. into
    %this MATLAB pipeline. Until then, as an alternative, I have found that
    %using the tried and true 'imopen' for background subtraction does a pretty
    %good job at removing out of focus light as long as the structuring element
    %is of an appropriate size (i.e. slightly bigger than a diffraction limited
    %spot).
    if p.Results.subtractbackground
        IM = JaredsBackground(IM);
    end
    %----- enhance diffraction limited spots using the LoG filter -----
    sigmaXYos = 0.21*wavelength/NA; %lateral st. dev of the gaussian filter in object space
    sigmaZos = 0.66*wavelength*rindex/(NA^2) ;%axial st. dev of the gaussian filter in object space
    Pxy = camerapixellength/objective; %lateral pixel size
    sigmaXY = sigmaXYos/Pxy; %lateral st. dev of gaussian filter in image space
    sigmaZ = sigmaZos/zstepsize; %axial st. dev of gaussian filter in image space
    xy = round(3*sigmaXY);
    z = round(3*sigmaZ);
    K = 1/((2*pi)^(3/2)*sqrt(sigmaXY^2*sigmaZ)); % log3d coefficient
    log3d = @(x,y,z) K*exp(-0.5*(x^2/sigmaXY+y^2/sigmaXY+z^2/sigmaZ))*((x^2-4*sigmaXY)/(4*sigmaXY^2)+(y^2-4*sigmaXY)/(4*sigmaXY^2)+(z^2-4*sigmaZ)/(4*sigmaZ^2));
    h = zeros(2*xy+1,2*xy+1,2*z+1);
    for i=1:2*xy+1
        for j=1:2*xy+1
            for k=1:2*z+1
                h(i,j,k) = log3d(i-1-xy,j-1-xy,k-1-z); %the 3D filter
            end
        end
    end
    %tune the filter so that it does not amplify the signal.
    temp1 = ones(2*xy+1,2*xy+1,2*z+1);
    h=-h; %otherwise the center weight, the largest weight, is negative.
    temp2 = sum(sum(sum(temp1.*h)));
    h=h/temp2;
    clear temp1;
    clear temp2;
    IM = imfilter(IM,h,'symmetric'); %Totally works. sweet!
    %----- calculate the test statistics that will identify legit spots -----
    %%%Test Statistic 1: The 3D curvature. Gives a sense about how much a spot
    %resembles a point source of light. It gives a sense of the spots geometry
    %as opposed to the brightness of the spot.
    curvature = mySobelHessianCurvature(IM);
    %A really large negative value indicates geometry like a point source. The
    %numbers produced are often extremely large and it may be a good idea to
    %normalize.
    %I turned a negative into a positive; I want you all to know that.
    curvature = abs(curvature);
    %%%Test Statistic 2: The mean brightness of the area. Indeed, we expect the
    %mRNA FISH signal to be brighter than the background. Taking the mean
    %reduces the weight of random peaks due to noise, since noise in these
    %images is of the zero-mean type.
    %find local maxima
    fociCandidates = imregionalmax(IM,26);
    %Find the mean of a local volume that will capture an entire point source.
    xy = round(4*sigmaXY);
    z = round(4*sigmaZ);
    IMPad = padarray(IM,[xy xy z],'symmetric');
    fociCandidatesPad = padarray(fociCandidates,[xy xy z]);
    index = find(fociCandidatesPad);
    clear fociCandidatesPad;
    s=size(IMPad);
    IMMeanIntensity = zeros(s);
    if iscolumn(index)
        index = index';
    end
    for i = index
        [i2,j2,k2] = ind2sub(s,i);
        localIntensityVolume=IMPad(i2-xy:i2+xy,j2-xy:j2+xy,k2-z:k2+z);
        IMMeanIntensity(i) = mean(mean(mean(localIntensityVolume)));
    end
    clear IMPad; %clear up some memory
    IMMeanIntensity = IMMeanIntensity(xy+1:end-xy,xy+1:end-xy,z+1:end-z);
    %The final test statistic is the product of test statistic 1 and 2
    spotStat = IMMeanIntensity.*curvature;
    %----- Find a threshold that separates signal from noise -----
    index = find(fociCandidates);
    clear fociCandidates
    if iscolumn(index)
        index = index';
    end
    spotStat = spotStat(index);
    %find a good guess for the threshold using the triangle threshold
    threshold = exp(trithresh(log(spotStat)));
    
    if isrow(spotStat)
        spotStat = spotStat';
    end
    if isrow(index)
        index = index';
    end
    spotStat = [spotStat,index]; %#ok<AGROW>
    spotStat = sortrows(spotStat,1);
    spotNum = size(spotStat,1);
    for i = 1:spotNum
        if spotStat(i,1) > threshold
            ind = i;
            break;
        end
    end
    %search around the threshold space centered at the intial guess and find
    %the threshold that minimizes the rate of change of foci count
    threshSearch = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    threshSearch = threshSearch*threshold;
    spotNumArray = zeros(size(threshSearch));
    for j = 1:length(threshSearch)
        for i = 1:spotNum
            if spotStat(i,1) > threshSearch(j)
                spotNumArray(j) = spotNum - i;
                break;
            end
        end
    end
    spotNumArrayDiff = diff(spotNumArray);
    [~,temp] = min(spotNumArrayDiff);
    ind = spotNum - spotNumArray(temp);
    s = size(IM);
    foci = zeros(s);
    for i = ind:spotNum
        foci(spotStat(i,2)) = 1;
    end
    %----- Create the final image with bonafide spots and other aesthetic images -----
    
    %sum projection of foci
    sumProj = sum(foci,3);
    Name = regexprep(stacknames2{bigInd},'(?<=_t)(\w*)(?=\.)','$1_sumProj');
    imwrite(sumProj,[smfishstackpath,'\',Name],'tif','WriteMode','append','Compression','none');
    %max project the stamp
    stampProj = zeros(size(foci));
    %gaussian stamp (approx. the PSF) on the sum projection of foci
    %3D Gaussian Filter\Stamp\PSF approximation
    mu = [0,0,0]; %zero mean gaussian
    SIGMA = [sigmaXY,0,0;0,sigmaXY,0;0,0,sigmaZ];
    h = zeros(2*xy+1,2*xy+1,2*z+1);
    for i=1:2*xy+1
        for j=1:2*xy+1
            for k=1:2*z+1
                h(i,j,k) = mvnpdf([i-1-xy,j-1-xy,k-1-z],mu,SIGMA); %the 3D filter
            end
        end
    end
    h=h*(2^14)/(max(max(max(h))));
    index = find(foci);
    if iscolumn(index)
        index = index';
    end
    s = size(foci);
    for i=index
        [i2,j2,k2] = ind2sub(s,i);
        stampProj(i2-xy:i2+xy,j2-xy:j2+xy,k2-z:k2+z) = stampProj(i2-xy:i2+xy,j2-xy:j2+xy,k2-z:k2+z) + h;
    end
    Name = regexprep(stacknames2{bigInd},'(?<=_t)(\w*)(?=\.)','$1_stampProj3D');
    for i = 1:s(3)
        imwrite(uint16(stampProj(:,:,i)),[smfishstackpath,'\',Name],'tif','WriteMode','append','Compression','none');
    end
    stampProj = sum(stampProj,3);
    Name = regexprep(stacknames2{bigInd},'(?<=_t)(\w*)(?=\.)','$1_stampProj');
    imwrite(stampProj,[smfishstackpath,'\',Name],'tif','WriteMode','append','Compression','none');
end
end

function [curvature] = mySobelHessianCurvature(I)
%This function uses the Sobel filter to approximate the derivatives in a
%gradient. Since the sobel filter is seperable the it can also be
%conveniently extended to find the Hessian.
%The image I is 3D and has coordinates (y,x,z).
h1 = [0.25 0.5 0.25];
h2 = [-0.5 0 0.5];
[~,sx,sz] = size(I);
tempI1 = zeros(size(I));
tempI2 = zeros(size(I));
%The Sobel separted filters to find the Fx
Fx = zeros(size(I));
for i=1:sx
    tempI1(:,i,:) = imfilter(I(:,i,:),h1,'symmetric'); %z
end
disp('1/27')
for i=1:sz
    tempI2(:,:,i) = imfilter(tempI1(:,:,i),h1,'symmetric'); %y
end
disp('2/27')
for i=1:sz
    Fx(:,:,i) = imfilter(tempI2(:,:,i),h2','symmetric'); %x
end
disp('3/27')
%The Sobel separted filters to find the Fy
Fy = zeros(size(I));
for i=1:sx
    tempI1(:,i,:) = imfilter(I(:,i,:),h1,'symmetric'); %z
end
disp('4/27')
for i=1:sz
    tempI2(:,:,i) = imfilter(tempI1(:,:,i),h2,'symmetric'); %y
end
disp('5/27')
for i=1:sz
    Fy(:,:,i) = imfilter(tempI2(:,:,i),h1','symmetric'); %x
end
disp('6/27')
%The Sobel separted filters to find the Fz
Fz = zeros(size(I));
for i=1:sx
    tempI1(:,i,:) = imfilter(I(:,i,:),h2,'symmetric'); %z
end
disp('7/27')
for i=1:sz
    tempI2(:,:,i) = imfilter(tempI1(:,:,i),h1,'symmetric'); %y
end
disp('8/27')
for i=1:sz
    Fz(:,:,i) = imfilter(tempI2(:,:,i),h1','symmetric'); %x
end
disp('9/27')
%The Sobel separted filters to find the Fxx
Fxx = zeros(size(I));
for i=1:sx
    tempI1(:,i,:) = imfilter(Fx(:,i,:),h1,'symmetric'); %z
end
disp('10/27')
for i=1:sz
    tempI2(:,:,i) = imfilter(tempI1(:,:,i),h1,'symmetric'); %y
end
disp('11/27')
for i=1:sz
    Fxx(:,:,i) = imfilter(tempI2(:,:,i),h2','symmetric'); %x
end
disp('12/27')
%The Sobel separted filters to find the Fxy
Fxy = zeros(size(I));
for i=1:sx
    tempI1(:,i,:) = imfilter(Fx(:,i,:),h1,'symmetric'); %z
end
disp('13/27')
for i=1:sz
    tempI2(:,:,i) = imfilter(tempI1(:,:,i),h1,'symmetric'); %y
end
disp('14/27')
for i=1:sz
    Fxy(:,:,i) = imfilter(tempI2(:,:,i),h2','symmetric'); %x
end
disp('15/27')
%The Sobel separted filters to find the Fxz
Fxz = zeros(size(I));
for i=1:sx
    tempI1(:,i,:) = imfilter(Fx(:,i,:),h1,'symmetric'); %z
end
disp('16/27')
for i=1:sz
    tempI2(:,:,i) = imfilter(tempI1(:,:,i),h1,'symmetric'); %y
end
disp('17/27')
for i=1:sz
    Fxz(:,:,i) = imfilter(tempI2(:,:,i),h2','symmetric'); %x
end
disp('18/27')
%The Sobel separted filters to find the Fyy
Fyy = zeros(size(I));
for i=1:sx
    tempI1(:,i,:) = imfilter(Fy(:,i,:),h1,'symmetric'); %z
end
disp('19/27')
for i=1:sz
    tempI2(:,:,i) = imfilter(tempI1(:,:,i),h2,'symmetric'); %y
end
disp('20/27')
for i=1:sz
    Fyy(:,:,i) = imfilter(tempI2(:,:,i),h1','symmetric'); %x
end
disp('21/27')
%The Sobel separted filters to find the Fyz
Fyz = zeros(size(I));
for i=1:sx
    tempI1(:,i,:) = imfilter(Fy(:,i,:),h1,'symmetric'); %z
end
disp('22/27')
for i=1:sz
    tempI2(:,:,i) = imfilter(tempI1(:,:,i),h2,'symmetric'); %y
end
disp('23/27')
for i=1:sz
    Fyz(:,:,i) = imfilter(tempI2(:,:,i),h1','symmetric'); %x
end
disp('24/27')
%The Sobel separted filters to find the Fzz
Fzz = zeros(size(I));
for i=1:sx
    tempI1(:,i,:) = imfilter(Fz(:,i,:),h2,'symmetric'); %z
end
disp('25/27')
for i=1:sz
    tempI2(:,:,i) = imfilter(tempI1(:,:,i),h1,'symmetric'); %y
end
disp('26/27')
for i=1:sz
    Fzz(:,:,i) = imfilter(tempI2(:,:,i),h1','symmetric'); %x
end
disp('27/27')
%Find the curvature matrix
clear tempI1;
clear tempI2;
curvature = zeros(size(I));
myHessian = zeros(3);
for i = 1:numel(I)
    myHessian(1,1) = Fxx(i);
    myHessian(1,2) = Fxy(i);
    myHessian(1,3) = Fxz(i);
    myHessian(2,1) = Fxy(i);
    myHessian(2,2) = Fyy(i);
    myHessian(2,3) = Fyz(i);
    myHessian(3,1) = Fxz(i);
    myHessian(3,2) = Fyz(i);
    myHessian(3,3) = Fzz(i);
    curvature(i) = det(myHessian);
end
end

function [trithresh]=trithresh(A)
%----- Approximate histogram as triangle -----
%Create the histogram
[n,xout]=hist(A,100);
%Find the highest peak the histogram
[c,ind]=max(n);
%Assume the long tail is to the right of the peak and envision a line from
%the top of this peak to the end of the histogram.
%The slope of this line, the hypotenuse, is calculated.
x1=0;
y1=c;
x2=length(n)-ind;
y2=n(end);
m=(y2-y1)/(x2-x1); %The slope of the line

%----- Find the greatest distance -----
%We are looking for the greatest distance betweent the histrogram and line
%of the triangle via perpendicular lines
%The slope of all lines perpendicular to the histogram hypotenuse is the
%negative reciprocal
p=-1/m; %The slope is now the negative reciprocal
%We now have two slopes and two points for two lines. We now need to solve
%this two-equation system to find their intersection, which can then be
%used to calculate the distances
iarray=(0:(length(n)-ind));
L=zeros(size(n));
for i=iarray
    intersect=(1/(m-p))*[-p,m;-1,1]*[c;n(i+ind)-p*i];
    %intersect(1)= y coordinate, intersect(2)= x coordinate
    L(i+ind)=sqrt((intersect(2)-i)^2+(intersect(1)-n(i+ind))^2);
end
[~,ind2]=max(L);
trithresh=xout(ind2);
end

function [S] = JaredsBackground(S)
resizeMultiplier = 1/2; % Downsampling scale factor makes image processing go faster and smooths image
seSize = 10; % I find the value of 10 works well with 60x, binning 1, mRNA FISH images
se = strel('disk', seSize*resizeMultiplier);  %Structing elements are necessary for using MATLABS image processing functions
origSize  = size(S);
for k=1:origSize(3)
    % Rescale image and compute background using closing/opening.
    I    = imresize(S(:,:,k), resizeMultiplier);
    pad   = ceil(seSize*resizeMultiplier);
    % Pad image with a reflection so that borders don't introduce artifacts
    I    = padarray(I, [pad,pad], 'symmetric', 'both');
    % Perform opening/closing to get background
    I     = imopen(I, se);     % ignore high-intensity features typical of mRNA spots
    % Remove padding and resize
    I     = floor(imresize(I(pad+1:end-pad, pad+1:end-pad), origSize(1:2)));
    S(:,:,k) = S(:,:,k) - I;
end
S(S<0)=0;
end

function [IM] = loadZstack(path)
info = imfinfo(path,'tif');
t = Tiff(path,'r');
IM_temp = t.read;
[leny,lenx] = size(IM_temp);
lenz = length(info);
IM = zeros(leny,lenx,lenz);
if lenz > 1
    for k=1:length(info)-1
        IM(:,:,k) = double(t.read);
        t.nextDirectory;
    end
    %one last time without t.nextDirectory
    IM (:,:,lenz) = double(t.read);
end
t.close;
end

function [Temp] = importStackNames(dirCon_stack,fc)
expr=['.*_w\d+' fc '.*_s\d+.*_t.*\.tif'];
Temp=cell([1,length(dirCon_stack)]); %Initialize cell array
% ----- Identify the legitimate stacks -----
i=1;
for j=1:length(dirCon_stack)
    Temp2=regexp(dirCon_stack(j).name,expr,'match','once','ignorecase');
    if Temp2
        Temp{i}=Temp2;
        i=i+1;
    end
end
% ----- Remove empty cells -----
Temp(i:end)=[];
% for j=length(Temp):-1:1
%     if isempty(Temp{j})
%         Temp(j)=[];
%     end
% end
end