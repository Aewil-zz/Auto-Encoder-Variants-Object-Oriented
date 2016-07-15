clc,clear;

% ��������
[ images4Train, labels4Train ] = loadMNISTData( 'dataSet/train-images.idx3-ubyte',...
    'dataSet/train-labels.idx1-ubyte', 'MinMaxScaler', 0 );

% Ҫ�Ȱ� AutoEncoder����calc_cost_grad method�����(Access = private)ע�͵�
[diff, numGradient, grad] = checkAE(images4Train); % ����AutoEncoder���Ƿ���ȷ
fprintf(['AE�м����ݶȵķ�����������ֵ�����Ĳ����ԣ�'...
    num2str(mean(abs(numGradient - grad)))...
    ' �� ' num2str(diff) '\n']);

% Ҫ�Ȱ� BackPropagation����calc_cost_grad method�����(Access = private)ע�͵�
[diff, numGradient, grad] = checkBP(images4Train, labels4Train);
fprintf(['BP�м����ݶȵķ�����������ֵ�����Ĳ����ԣ�'...
    num2str(mean(abs(numGradient - grad)))...
    ' �� ' num2str(diff) '\n']);








