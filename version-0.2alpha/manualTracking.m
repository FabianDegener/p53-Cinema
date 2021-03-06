function varargout = manualTracking(varargin)
% MANUALTRACKING MATLAB code for manualTracking.fig
%      MANUALTRACKING, by itself, creates a new MANUALTRACKING or raises the existing
%      singleton*.
%
%      H = MANUALTRACKING returns the handle to a new MANUALTRACKING or the handle to
%      the existing singleton*.
%
%      MANUALTRACKING('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MANUALTRACKING.M with the given input arguments.
%
%      MANUALTRACKING('Property','Value',...) creates a new MANUALTRACKING or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before manualTracking_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to manualTracking_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help manualTracking

% Last Modified by GUIDE v2.5 03-Oct-2012 08:55:58

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @manualTracking_OpeningFcn, ...
    'gui_OutputFcn',  @manualTracking_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before manualTracking is made visible.
function manualTracking_OpeningFcn(hObject, eventdata, handles, varargin) %#ok<*INUSL>
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to manualTracking (see VARARGIN)

% Choose default command line output for manualTracking
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

handles.ind = 1;
handles.timeind = 1;
fluorchan = get(handles.editFluorescentChannels, 'String'); %assume CSV
C = textscan(fluorchan, '%s', 'delimiter', ', ', 'MultipleDelimsAsOne', 1);
handles.fluorescentChannels = C{1};
handles.renderfig = figure('Visible','off');
guidata(hObject, handles);
% UIWAIT makes manualTracking wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = manualTracking_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function editLogPath_Callback(hObject, eventdata, handles) %#ok<*INUSD>
% hObject    handle to editLogPath (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editLogPath as text
%        str2double(get(hObject,'String')) returns contents of editLogPath as a double


% --- Executes during object creation, after setting all properties.
function editLogPath_CreateFcn(hObject, eventdata, handles)
% hObject    handle to editLogPath (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbuttonLogPath.
function pushbuttonLogPath_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonLogPath (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

folder_name = uigetdir;
set(handles.editLogPath,'String',folder_name);



function editStackPath_Callback(hObject, eventdata, handles)
% hObject    handle to editStackPath (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editStackPath as text
%        str2double(get(hObject,'String')) returns contents of editStackPath as a double


% --- Executes during object creation, after setting all properties.
function editStackPath_CreateFcn(hObject, eventdata, handles)
% hObject    handle to editStackPath (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbuttonStackPath.
function pushbuttonStackPath_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonStackPath (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

folder_name = uigetdir;
set(handles.editStackPath,'String',folder_name);


% --- Executes on button press in pushbuttonExtractData.
function pushbuttonExtractData_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonExtractData (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.textStepTwoFinished, 'Visible', 'off');
pause(0.1); %this
logpath = get(handles.editLogPath, 'String');
stackpath = get(handles.editStackPath, 'String');
fluorchan = get(handles.editFluorescentChannels, 'String'); %assume CSV
C = textscan(fluorchan, '%s', 'delimiter', ', ', 'MultipleDelimsAsOne', 1);
handles.fluorescentChannels = C{1};
phaseratio = str2double(get(handles.editRatio,'String'));
for i = 1:length(C{1})
    
    processManualSegTrackViaImageJ(logpath, stackpath, 'fluorchan', C{1}{i},'phaseratio',phaseratio)
end
c = clock;
set(handles.textStepTwoFinished, 'String', sprintf('Finished! @ %02d:%02d',c(4),c(5)));
set(handles.textStepTwoFinished, 'Visible', 'on');
str = sprintf('dynamics%s', C{1}{1});
set(handles.editDataPath, 'String', fullfile(logpath,str));
guidata(hObject, handles);




function editFluorescentChannels_Callback(hObject, eventdata, handles)
% hObject    handle to editFluorescentChannels (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editFluorescentChannels as text
%        str2double(get(hObject,'String')) returns contents of editFluorescentChannels as a double


% --- Executes during object creation, after setting all properties.
function editFluorescentChannels_CreateFcn(hObject, eventdata, handles)
% hObject    handle to editFluorescentChannels (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbuttonPrev.
function pushbuttonPrev_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonPrev (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if handles.ind~=1
    handles.ind = handles.ind - 1;
end
updateGUI(handles);
updateImageAxes(handles)
plot(handles.axes1, handles.data(handles.ind).meanIntensity);
guidata(hObject, handles);

% --- Executes on button press in pushbuttonNext.
function pushbuttonNext_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonNext (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if handles.ind~=length(handles.data)
    handles.ind = handles.ind + 1;
end
updateGUI(handles);
updateImageAxes(handles)
plot(handles.axes1, handles.data(handles.ind).meanIntensity);
guidata(hObject, handles);


function editCurrentCell_Callback(hObject, eventdata, handles)
% hObject    handle to editCurrentCell (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editCurrentCell as text
%        str2double(get(hObject,'String')) returns contents of editCurrentCell as a double
currentInd = str2double(get(handles.editCurrentCell,'String'));
handles.ind = currentInd;
updateGUI(handles);
updateImageAxes(handles)
plot(handles.axes1, handles.data(handles.ind).meanIntensity);
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function editCurrentCell_CreateFcn(hObject, eventdata, handles)
% hObject    handle to editCurrentCell (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function editDataPath_Callback(hObject, eventdata, handles)
% hObject    handle to editDataPath (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editDataPath as text
%        str2double(get(hObject,'String')) returns contents of editDataPath as a double


% --- Executes during object creation, after setting all properties.
function editDataPath_CreateFcn(hObject, eventdata, handles)
% hObject    handle to editDataPath (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbuttonDataPath.
function pushbuttonDataPath_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonDataPath (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[filename, foldername, ~] = uigetfile;
set(handles.editDataPath,'String',fullfile(foldername, filename));

% --- Executes on button press in pushbuttonLoadData.
function pushbuttonLoadData_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonLoadData (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.PhaseFilenames = importStackNames(get(handles.editPhasePath,'String'),get(handles.editPhaseName,'String'));
handles.PhaseFilenamesKey = positiondecypher(handles.PhaseFilenames);
fluorchan = get(handles.editFluorescentChannels, 'String'); %assume CSV
C = textscan(fluorchan, '%s', 'delimiter', ', ', 'MultipleDelimsAsOne', 1);
handles.fluorescentChannels = C{1};
for i=1:length(handles.fluorescentChannels)
    handles.fluorescentFilenames{i} = importStackNames(get(handles.editStackPath,'String'),handles.fluorescentChannels{i});
    handles.fluorescentFilenamesKey{i} = positiondecypher(handles.fluorescentFilenames{i});
end
datapath = get(handles.editDataPath, 'String');
load(datapath);
c = clock;
set(handles.textLoadData, 'String', sprintf('Data Loaded! @ %02d:%02d',c(4),c(5)));
set(handles.textLoadData, 'Visible', 'on');
handles.data = unitOfLife;
handles.numberOfCellsTotal = length(handles.data);
handles.timeind = 1;
plot(handles.axes1, handles.data(handles.ind).meanIntensity);
updateGUI(handles);
updateImageAxes(handles)
guidata(hObject, handles);



function editRatio_Callback(hObject, eventdata, handles)
% hObject    handle to editRatio (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editRatio as text
%        str2double(get(hObject,'String')) returns contents of editRatio as a double


% --- Executes during object creation, after setting all properties.
function editRatio_CreateFcn(hObject, eventdata, handles)
% hObject    handle to editRatio (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function slider1_Callback(hObject, eventdata, handles)
% hObject    handle to slider1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

function updateGUI(handles)
set(handles.editCurrentCell,'String',num2str(handles.ind));
set(handles.textNumcell, 'String', sprintf('of %d',handles.numberOfCellsTotal));

function updateImageAxes(handles)
phasepath = get(handles.editPhasePath,'String');
logpath = get(handles.editLogPath,'String');
if exist(phasepath,'dir') && exist(logpath,'dir')
%1. Show the entire field of view
axes2width = get(handles.axes2, 'Position');
axes2height = axes2width(4);
axes2width = axes2width(3);
%derive the phase stack number
positionind = regexp(handles.data(handles.ind).originImageFileName,'_s(\d+)','tokens');
positionind = str2double(positionind{1});
tPhase = Tiff(fullfile(phasepath,handles.PhaseFilenames{handles.PhaseFilenamesKey(positionind)}),'r');
tPhase.setDirectory(handles.timeind);
I = tPhase.read();
%in case images are 12-bit instead of the 16-bit TIFF container
Iresize = imresize(I, [axes2height axes2width]);
if max(max(I))<=4095
    imshow(Iresize,[],'Parent',handles.axes2);
else
    imshow(Iresize,'Parent',handles.axes2);
end
tPhase.close();
%2. Show a close up of the cell (2x)
%For the moment the window size will not be changable.
myCentroid = handles.data(handles.ind).manualCentroid(handles.timeind,:); %myCentroid = [row, col] = [y, x]
xm = round(myCentroid(2));
ym = round(myCentroid(1));
Iwidth = size(I,2);
Iheight = size(I,1);
x1 = xm + 83;
x2 = xm - 84;
y1 = ym + 63;
y2 = ym - 64;
if x1 > Iwidth
    x1 = Iwidth;
    x2 = Iwidth - 167;
elseif x2 < 1
    x1 = 168;
    x2 = 1;
end
if y1 > Iheight
    y1 = Iheight;
    y2 = Iheight-127;
elseif y2 < 1
    y1 = 128;
    y2 = 1;
end

%account for y being at the lower left corner and not upper left?
%y1 = Iheight + 1 - y1;
%y2 = Iheight + 1 - y2;

I2 = I(y2:y1,x2:x1);
%add the yellow ellipse
xellipse=zeros(38,1);
            yellipse=zeros(38,1);
            rho = (0:9:333)/53;
            rhocos=cos(rho);
            rhosin=sin(rho);
if handles.data(handles.ind).angle(handles.timeind) == 0 || handles.data(handles.ind).angle(handles.timeind) == 180
                    a = round(handles.data(handles.ind).major(handles.timeind)/2);
                    b = round(handles.data(handles.ind).minor(handles.timeind)/2);
                elseif handles.data(handles.ind).angle(handles.timeind) == 90 || handles.data(handles.ind).angle(handles.timeind) == 270
                    a = round(handles.data(handles.ind).minor(handles.timeind)/2);
                    b = round(handles.data(handles.ind).major(handles.timeind)/2);
end
for k=1:38
                    x=xm+a*rhocos(k);
                    y=ym+b*rhosin(k);
                    xellipse(k) = round(x);
                    yellipse(k) = round(y);
end
set(0, 'CurrentFigure', handles.renderfig);
clf(handles.renderfig);

imshow(I,[]);
hold on
for k=1:37
    line([xellipse(k) xellipse(k+1)],[yellipse(k) yellipse(k+1)],'color','yellow','LineWidth',2);
end
hold off
filename = fullfile(logpath,'.temprenderfig.tif');
print(handles.renderfig, '-dtiff', filename);
I2 = imread(filename,'tiff');
Iresize = imresize(I2,2);
    imshow(Iresize,'Parent',handles.axes3);


%3. Show a close up of the fluorescent channel

tFluo = Tiff(fullfile(get(handles.editStackPath,'String'),handles.fluorescentFilenames{1}{handles.fluorescentFilenamesKey{1}(positionind)}),'r');
tFluo.setDirectory(handles.timeind);
I = tFluo.read();
I3 = I(y2:y1,x2:x1);
Iresize = imresize(I3,2);
%in case images are 12-bit instead of the 16-bit TIFF container
    imshow(Iresize,[],'Parent',handles.axes4);
tFluo.close();
end



function editPhasePath_Callback(hObject, eventdata, handles)
% hObject    handle to editPhasePath (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editPhasePath as text
%        str2double(get(hObject,'String')) returns contents of editPhasePath as a double


% --- Executes during object creation, after setting all properties.
function editPhasePath_CreateFcn(hObject, eventdata, handles)
% hObject    handle to editPhasePath (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton8.
function pushbutton8_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
folder_name = uigetdir;
set(handles.editPhasePath,'String',folder_name);

function [Temp] = importStackNames(stackpath,fc)
dirCon_stack  = dir(stackpath);
expr=['.*(?<!thumb.*)_w\d+' fc '.*'];
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

function [out] = positiondecypher(in)
out = zeros(size(in));
for i = 1:length(out);
positionind = regexp(in{i},'_s(\d+)','tokens');
out(i) = str2double(positionind{1});
end
temp = 1:length(out);
temp = [out;temp]';
temp = sortrows(temp,1);
out = temp(:,2);

function editPhaseName_Callback(hObject, eventdata, handles)
% hObject    handle to editPhaseName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editPhaseName as text
%        str2double(get(hObject,'String')) returns contents of editPhaseName as a double


% --- Executes during object creation, after setting all properties.
function editPhaseName_CreateFcn(hObject, eventdata, handles)
% hObject    handle to editPhaseName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


%To make cool movie for iPhone5 (and 16:9) resize images by 4x and collect
%a 1136 x 640 subsection.
