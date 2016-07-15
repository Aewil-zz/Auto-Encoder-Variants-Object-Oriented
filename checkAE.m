function [diff, numGradient, grad] = checkAE(images)
%���ڼ��AutoEncoder�����õ����ݶ�grad�Ƿ���Ч
% by ֣��ΰ Aewil 2016-04
% ��������ֵ�����ݶȵķ����õ��ݶ�numGradient����������
% ��AutoEncoder�ࣨ��ѧ�����������õ����ݶȣ��ܿ죩���бȽ�
% �õ������ݶ�������ŷʽ�����С��Ӧ�÷ǳ�֮С�Ŷԣ�

image = images(:, 1:1);% ��Ϊ������������Բų�ȡһ�����������ͼ��theta��308308ά����
architecture = [ 784 196 784 ]; % AE����Ľṹ: inputSize -> hiddenSize -> outputSize
activations  = { 'Sigmoid', 'Sigmoid' };
option4AE.isSparse    = 1;
option4AE.sparseRho   = 0.1;
option4AE.sparseBeta  = 3;
option4AE.isDenoising = 0;
option4AE.decayLambda = 1;

auto_encoder = AutoEncoder(architecture, activations, option4AE);

% ��������
[ ~,grad] = auto_encoder.calc_cost_grad(image, auto_encoder.theta);

% ��ֵ���㷽��
numGradient = computeNumericalGradient( ...
    @(x) auto_encoder.calc_cost_grad(image, x), auto_encoder.theta);

% �Ƚ��ݶȵ�ŷʽ����
diff = norm( numGradient - grad ) / norm( numGradient + grad );

end






function numGradient = computeNumericalGradient( fun, theta )
%����ֵ�������� ����fun �� ��theta �����ݶ�
% fun��������theta�����ʵֵ�ĺ��� y = fun( theta )
% theta����������

    % ��ʼ�� numGradient
    numGradient = zeros( size(theta) );

    % ��΢�ֵ�ԭ���������ݶȣ�����һ��С�仯�󣬺���ֵ�ñ仯�̶�
    EPSILON   = 1e-4;
    upTheta   = theta;
    downTheta = theta;
    
    wait = waitbar(0, '��ǰ����');
    for i = 1: length( theta )
        % waitbar( i/length(theta), wait, ['��ǰ����', num2str(i/length(theta)),'%'] );
        waitbar( i/length(theta), wait);
        
        upTheta( i )    = theta( i ) + EPSILON;
        [ resultUp, ~ ] = fun( upTheta );
        
        downTheta( i )    = theta( i ) - EPSILON;
        [ resultDown, ~ ] = fun( downTheta );
        
        numGradient( i )  = ( resultUp - resultDown ) / ( 2 * EPSILON ); % d Vaule / d x
        
        upTheta( i )   = theta( i );
        downTheta( i ) = theta( i );
    end
    bar  = findall(get(get(wait, 'children'), 'children'), 'type', 'patch');
    set(bar, 'facecolor', 'g');
    close(wait);
end
