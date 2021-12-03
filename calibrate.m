close all;
% Auto-generated by cameraCalibrator app on 30-Nov-2021
%-------------------------------------------------------


% Define images to process
path = 'C:\Users\Administrator\Desktop\folder\';
imageFileNames = {'IMG_0193.JPG_pts.png',...
    'IMG_0194.JPG_pts.png',...
    'IMG_0195.JPG_pts.png',...
    'IMG_0197.JPG_pts.png',...
    'IMG_0199.JPG_pts.png',...
    'IMG_0200.JPG_pts.png',...
    'IMG_0201.JPG_pts.png',...
    'IMG_0204.JPG_pts.png',...
    'IMG_0208.JPG_pts.png',...
    'IMG_0209.JPG_pts.png',...
    'IMG_0211.JPG_pts.png',... 
    };
l = size(imageFileNames);
for i = 1:l(2)
    imageFileNames{i} = [path, imageFileNames{i}];
end

% Detect checkerboards in images
[imagePoints, boardSize, imagesUsed] = detectCheckerboardPoints(imageFileNames);
imageFileNames = imageFileNames(imagesUsed);

% Read the first image to obtain image size
originalImage = imread(imageFileNames{1});
[mrows, ncols, ~] = size(originalImage);

% Generate world coordinates of the corners of the squares
squareSize = 3.470000e+01;  % in units of 'millimeters'
worldPoints = generateCheckerboardPoints(boardSize, squareSize);

% Calibrate the camera
[cameraParams, imagesUsed, estimationErrors] = estimateCameraParameters(imagePoints, worldPoints, ...
    'EstimateSkew', false, 'EstimateTangentialDistortion', false, ...
    'NumRadialDistortionCoefficients', 2, 'WorldUnits', 'millimeters', ...
    'InitialIntrinsicMatrix', [], 'InitialRadialDistortion', [], ...
    'ImageSize', [mrows, ncols]);

% View reprojection errors
h1=figure; showReprojectionErrors(cameraParams);

% Visualize pattern locations
h2=figure; showExtrinsics(cameraParams, 'CameraCentric');

% Display parameter estimation errors
displayErrors(estimationErrors, cameraParams);

% For example, you can use the calibration data to remove effects of lens distortion.
undistortedImage = undistortImage(originalImage, cameraParams);

% See additional examples of how to use the calibration data.  At the prompt type:
% showdemo('MeasuringPlanarObjectsExample')
% showdemo('StructureFromMotionExample')

%%
A =cameraParams.IntrinsicMatrix';
D = [cameraParams.RadialDistortion 0 0 0];
fx = A(1,1);
fy = A(2,2);
cx = A(1,3);
cy = A(2,3);
k1 = D(1);
k2 = D(2);
k3 = D(5);
p1 = D(3);
p2 = D(4);

K = A;
point_correct = zeros(24,2,l(2));

for j = 1:l(2)
I_d = imread(imageFileNames{j});
I_d = rgb2gray(I_d);
I_d = im2double(I_d);
%I_d = [cameraParams.ReprojectedPoints(:,1,j),cameraParams.ReprojectedPoints(:,2,j)];
 
I_r = zeros(size(I_d));
 
%图像坐标系和矩阵的表示是相反的
%[row,col] = find(X)，坐标按照列的顺序排列，这样好和reshape()匹配出响应的图像矩阵
[v, u] = find(~isnan(I_r));
 
% XYZc 摄像机坐标系的值，但是已经归一化了，因为没有乘比例因子
%公式 s[u v 1]' = A*[Xc Yc Zc]' ，其中s为比例因子，不加比例因子，Zc就为1，所以此时的Xc相对于( Xc/Zc )
XYZc= inv(A)*[u v ones(length(u),1)]';
 
% 此时的x和y是没有畸变的
r2 = XYZc(1,:).^2+XYZc(2,:).^2;
x = XYZc(1,:);
y = XYZc(2,:);

% x和y进行畸变的
px = x.*(1+k1*r2 + k2*r2.^2) + 2*p1.*x.*y + p2*(r2 + 2*x.^2);
py = y.*(1+k1*r2 + k2*r2.^2) + 2*p2.*x.*y + p1*(r2 + 2*y.^2);
x=px;
y=py;

% (u, v) 对应的畸变坐标 (u_d, v_d)
u_d = reshape(fx*x + cx,size(I_r));
v_d = reshape(fy*y + cy,size(I_r));

[height, width] = size(I_d); 
% 线性插值出非畸变的图像 解释见最后
I_r = interp2(1:width, 1:height, I_d, u_d, v_d);
%point_correct(:,:,j) = I_r;

% %对比图像
% subplot(121);     
% imagesc(I_d);
% title('畸变原图像');
% subplot(122);
% imshow(I_r);
% title('校正后图像');
% image_path = imageFileNames{j};
% imwrite(I_r, [image_path(1:38),'new\',image_path(39:end)]); %new\


for i = 1:24
    x=cameraParams.ReprojectedPoints(i,1,j);
    y=cameraParams.ReprojectedPoints(i,2,j);
    x=round(x);
    y=round(y);
    
    point_correct(i,1,j) = u_d(y,x);
    point_correct(i,2,j) = v_d(y,x);
end
    
end

%{
(1)ZI = interp2(X,Y,Z,XI,YI)

好多文章里巴拉巴拉说了一堆，迷迷糊糊的，我还是用我的大白话叙述一下：

X,Y是原始数据，相当于坐标，类似于meshgrid的坐标范围，这么说应该很容易理解......

Z是在上述坐标下的数值，也就是在坐标[xi  yi]下的zi

XI,YI就是用于插值的坐标，

返回值ZI就是用于提取插值之后，对应位置的值

这里需要注意：

X 与Y必须是单调的

若Xi与Yi中有在X与Y范围之外的点，则相应地返回nan(Not a Number)



下面是其他形式的解释，这个我就直接copy啦~~

(2)ZI = interp2(Z,XI,YI)
缺省地，X=1:n、Y=1:m，其中[m,n]=size(Z)。再按第一种情形进行计算。
%}