function []=flatfieldcorrection(stackpath,ffpath,varargin)
% [] = flatfieldcorrection(stackpath,ffpath)
% Input:
% stackpath: the location of TIFF that will be flat field corrected
% ffpath: the location of the correction images
%
% Output:
% There is no direct argument output. Rather, new stacks will be created from
% the stacks found in the stackpath directory and stored in a folder called
% [stackpath '_ff'].
%
% Description:
%
%
% Other Notes:
% Assumes the image files have been converted to the p53Cinema PNG format
p = inputParser;
p.addRequired('stackpath', @(x)ischar(x));
p.addRequired('ffpath', @(x)ischar(x));
p.parse(stackpath,ffpath, varargin{:});

%----- Import PNG paths -----
%Check whether the computer is a mac
if ismac
    error('ffcor:notApc','Flatfield correction is currently configured to run on a pc');
    %[~,filepaths]=system('ls -Rp */*.png');
elseif ispc
    %the 'dir' command in Matlab does not search subfolders. However,
    %there is a MS-DOS command that will do the trick!
    %'/B' uses bare format (no heading information or summary)
    %'/S' displays files in specified directory and all subdirectories
    cd(stackpath)
    [~,filepaths] = system('dir /S /B *.png');
    filepaths = textscan(filepaths,'%s');
    filepaths = filepaths{1};
else
    error('ffcor:notApc','Flatfield correction is currently configured to run on a pc');
end
disp(['working in ', stackpath]); %Sanity Check

%import directory of flatfield images
disp(['working in ', ffpath]); %Sanity Check
dirCon_ff = dir(ffpath);
%only the channels with flat field images can be corrected. identify those
%channels
expr='.+(?=_)';
Temp=cell([1,length(dirCon_ff)]); %Initialize cell array
i=1;
for j=1:length(dirCon_ff)
    Temp2=regexp(dirCon_ff(j).name,expr,'match','once','ignorecase');
    if Temp2
        Temp{i}=Temp2;
        i=i+1;
    end
end
Temp(i:end)=[];
channels_stacks = unique(Temp); %The different channels are saved

if isempty(channels_stacks)
    error('fltfldcrct:noFF','There are no matching flatfield images.')
end
%----- Create a new folder to hold corrected images -----
foldernameIN=regexp(stackpath,'(?<=\\)[\w ]*','match'); %Prepare to create a new folder to place background subtracted stacks
foldernameIN = foldernameIN{end};
foldernameOUT=[foldernameIN,'_ff'];
ffstackpath=regexprep(stackpath,foldernameIN,foldernameOUT);
mkdir(ffstackpath);

%Create channelTruthTable variable. The channelTruthTable variable is two
%columns with a row for each channel. The first column is the offset
%column, 1 if offset image exists 0 otherwise. The second column is the
%gain column, 1 if gain image exists 0 otherwise.
channelTruthTable = zeros(length(channels_stacks),2);
%---- check for existence of correction images ----
%first, identify offset  and gain images and their channel
expr='.+(?=_offset.tif)';
for j=1:length(dirCon_ff)
    Temp2=regexp(dirCon_ff(j).name,expr,'match','once','ignorecase');
    if Temp2
        for k=1:length(channels_stacks)
            if strcmpi(Temp2,channels_stacks{k})
                channelTruthTable(k,1) = 1;
            end
        end
    end
end
expr='.+(?=_gain\d+.tif)';
for j=1:length(dirCon_ff)
    Temp2=regexp(dirCon_ff(j).name,expr,'match','once','ignorecase');
    if Temp2
        for k=1:length(channels_stacks)
            if strcmpi(Temp2,channels_stacks{k})
                channelTruthTable(k,2) = 1;
            end
        end
    end
end
%create offset and gain images according to the truth table
for i=1:length(channels_stacks)
    outcome = channelTruthTable(i,1)*2 + channelTruthTable(i,2);
    switch outcome
        case 0 %No offset or gain image
            makeoffset(channels_stacks{i},ffpath);
            makegain(channels_stacks{i},ffpath,dirCon_ff);
        case 1 %just a gain image
            makeoffset(channels_stacks{i},ffpath);
        case 2 %just an offset image
            makegain(channels_stacks{i},ffpath,dirCon_ff);
        case 3 %both gain and offset exist
    end
end

%---- correct stacks using correction images ----
dirCon_ff = dir(ffpath);
for j=1:length(channels_stacks)
    info = imfinfo([ffpath,'\',channels_stacks{j},'_offset'],'tif');
    offset = double(imread([ffpath,'\',channels_stacks{j},'_offset'],'tif','Info',info));
    offset = scale12to16bit(offset);
    for k=1:length(dirCon_ff)
        temp = regexp(dirCon_ff(k).name,[channels_stacks{j} '_gain\d+'],'match','once','ignorecase');
        if ~isempty(temp)
            gainname = temp;
            break
        end
    end
    info = imfinfo([ffpath,'\',gainname],'tif');
    gain = double(imread([ffpath,'\',gainname],'tif','Info',info));
    expr='(?<=_gain)\d+';
    max_temp=regexp(gainname,expr,'match','once');
    max_temp=str2double(max_temp)/1000;
    gain=gain*max_temp/65536;
    
    for i=1:length(filepaths)
        [~,pngname,~] = fileparts(filepaths{i});
        temp = regexp(pngname,channels_stacks{j},'match','once','ignorecase');
        if ~isempty(temp)
            disp(['Flatfield correcting ',filepaths{i}])
            IM = double(imread(filepaths{i}));
            Name = regexprep(filepaths{i},foldernameIN,foldernameOUT);
            [pngpath,~,~] = fileparts(Name);
            %verify that the input image is the correct size, otherwise no
            %output image will be created.
            if size(IM)~=size(offset)
                continue
            end
            IM = IM-offset;
            IM(IM<0) = 0;
            IM = IM./gain;
            IM = uint16(IM);
            %check for the existence of the folder where the new image will be placed.
            if ~isdir(pngpath)
                mkdir(pngpath);
            end
            %Create the PNG
            imwrite(IM,Name,'png','bitdepth',16);
        end
        %update metadata?
        
    end
end
signalCompletionWithSound();
end

%----- SUBFUNCTION LEASTSQUARESFIT -----
function [a,b]=leastsquaresfit(x,y,j,k)
xm=mean(x);
ym=mean(y);
SSxx=sum(x.*x)-length(x)*xm^2;
SSyy=sum(y.*y)-length(y)*ym^2;
SSxy=sum(x.*y)-length(x)*xm*ym;
b=SSxy/SSxx;
a=ym-b*xm;
r2=(SSxy^2)/(SSxx*SSyy);
if r2<0.8
    disp(['not a good fit. x=', num2str(k), ' y=', num2str(j)])
end
end

%----- SUBFUNCTION XYSMOOTHEN -----
function [I]=xysmoothen(I,windowsize)
ho=size(I,1); %original height of the input image (usually 512)
wo=size(I,2); %original width of the input image (usually 672)
I2=zeros(size(I));
%ensure the window size is odd
odd=mod(windowsize,2);
if ~odd
    windowsize=windowsize+1;
end
a=1/windowsize^2;
padsize=(windowsize-1)/2;
I=padarray(I,[padsize padsize],'symmetric');
jarray=(1+padsize:1:ho+padsize);
karray=(1+padsize:1:wo+padsize);
winarray=(1:windowsize)-(padsize+1);
for j=jarray
    for k=karray
        b=0;
        for q=winarray
            for r=winarray
                b=b+I(j+q,k+r);
            end
        end
        I2(j-padsize,k-padsize)=a*b;
    end
end
I=I2;
end

%----- SUBFUNCTION MAKEOFFSET -----
function []=makeoffset(chan,ffpath)
disp(['making offset image for the ' chan ' channel...'])
info = imfinfo([ffpath,'\',chan,'_0'],'tif');
IM=double(imread([ffpath,'\',chan,'_0'],'tif','Info',info));
IM=xysmoothen(IM,9);
IM=floor(IM);
IM=uint16(IM);
imwrite(IM,[ffpath,'\',chan,'_offset.tif'],'tif','Compression','none');
end

%----- SUBFUNCTION MAKEGAIN -----
function []=makegain(chan,ffpath,dirCon_ff)
disp(['making gain image for the ' chan ' channel...'])
%identify all the exposure images
Temp=cell([1,length(dirCon_ff)]); %Initialize cell array
% ----- Identify the legitimate stacks -----
expr=[chan '(?=_\d+)'];
i=1;
for j=1:length(dirCon_ff)
    Temp2=regexp(dirCon_ff(j).name,expr,'match','once','ignorecase');
    if Temp2
        Temp{i}=dirCon_ff(j).name;
        i=i+1;
    end
end
% ----- Remove empty cells -----
Temp(i:end)=[];
%identify the length of exposure for each image
expr=[chan '_(\d+)'];
exposure = zeros(size(Temp));
flatfieldIM = cell(size(Temp));
for i=1:length(Temp)
    [~, temp_num] = regexp(Temp{i},expr,'match','once','tokens');
    exposure(i) = str2double(temp_num);
    if exposure == 0
        ind = i;
    end
    info = imfinfo([ffpath,'\',chan,'_0'],'tif');
    flatfieldIM{i}=double(imread([ffpath,'\',Temp{i}],'tif','Info',info));
end

%weight the dark image by 5
Temp = zeros(1,5);
exposure = [exposure Temp];
Temp = cell(1,5);
flatfieldIM = [flatfieldIM Temp];
for i=0:4
    flatfieldIM{end-i} = flatfieldIM{ind};
end
%calculate the gain image
[hei,wid]=size(flatfieldIM{1});
gainIM=zeros(size(flatfieldIM{1}));
for j=1:hei
    for k=1:wid
        [x,y]=deal(zeros(length(exposure),1));
        for i=1:length(exposure)
            y(i)=flatfieldIM{i}(j,k);
            x(i)=exposure(i);
        end
        [~,b]=leastsquaresfit(x,y);
        gainIM(j,k)=b;
    end
end
gainIM=gainIM/mean(mean(gainIM));
gainIM=xysmoothen(gainIM,5);
max_temp=max(max(gainIM));
max_temp=round(max_temp*1000)/1000;
im_temp=gainIM*65536/max_temp;
im_temp=uint16(im_temp);
max_temp=sprintf('%d',max_temp*1000);
imwrite(im_temp,[ffpath,'\',chan,'_gain',max_temp,'.tif'],'tif','Compression','none');
end

%----- SUBFUNCTION SCALE12TO16BIT -----
function [IM] = scale12to16bit(IM)
%input:
%IM = an image with bit depth 12
%
%output:
%IM = a scaled image with bit depth 16
%description:
%The class of the image is detected. Depending on the class type an image
%maybe converted into an integer format and then converted back into the
%format of the input.
%
%other notes:
%The Hamamatsu cameras for the closet scope and curtain scope create images
%with 12-bit dynamic range. However, the TIFF format that stores these
%images uses a 16-bit format. Viewing a 12-bit image in a 16-bit format on
%a computer monitor is complicated by the scaling being done at 16-bit. To
%make viewing images from the microscope easier on a computer monitor,
%without any compression or loss of data, the 12-bit data is shifted left
%4-bits to become 16-bit data.
numType = class(IM);
switch numType
    case 'double'
        IM = uint16(IM);
        IM = bitshift(IM,4);
        IM = double(IM);
    case 'uint16'
        IM = bitshift(IM,4);
end
end

function [] = signalCompletionWithSound()
global playerkwk
if ~isempty(playerkwk)
    play(playerkwk);
else
    disp('Victory over Data!')
end
end