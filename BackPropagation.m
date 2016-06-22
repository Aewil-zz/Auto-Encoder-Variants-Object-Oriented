classdef BackPropagation < Feedforward_Neural_Network
    % һ��ȫ����ǰ��BP����
    % by ֣��ΰ Aewil 2016-05
    
    % ����ṹ���������ֻ�г�ʼ��ʱ����������Ҳ���ɸģ�����ѡ��ɸ�
    properties(SetAccess = private, GetAccess = public)
        %����ṹ
        architecture
        %ÿһ�㼤�������
        activations
        %�������
        theta
    end
    properties(SetAccess = public, GetAccess = public)
        %����ѡ���ΪҪ�޸�weighted_cost
        options
    end
    properties(Hidden, SetAccess = private, GetAccess = public)
        %��������
        parameters_num = 0;
        %����
        layers         = 0;
    end
    properties(Hidden, Constant)
        %��ѡ������б�
        activations_list = char('Sigmoid', 'tanh',...
            'ReLU', 'leaky_ReLU', 'parameter_ReLU', 'softmax');
    end
    
    methods
        %ʵ������Ļ������ܣ���ʼ����ѵ����Ԥ�⡢���ԡ�չʾ
        
        function obj = BackPropagation(architecture, activations, options, theta)
            %���캯������������ṹ���������Ԫ���顢����Ԥѡ��������
            if isa(architecture, 'double')
                obj.architecture = architecture;
            else
                error('BP����ṹ������һ�������б�!');
            end
            obj.layers = length(obj.architecture);
            
            if exist('activations', 'var')
                obj.initialize_activations(activations);
            else
                obj.initialize_activations();
            end
            
            if exist('options', 'var')
                obj.initialize_options(options);
            else
                obj.initialize_options();
            end
            
            obj.parameters_num = sum((obj.architecture(1:end-1) + 1) .* obj.architecture(2:end));
            if strcmp(obj.activations{end}, 'softmax')
                obj.parameters_num = obj.parameters_num - obj.architecture(end);    
            end
            
            if exist('theta', 'var')
                obj.initialize_parameters(theta);
            else
                obj.initialize_parameters();
            end
        end
        function target = predict(obj, input)
            %ǰ��������
            for layer_num = 1:(obj.layers - 1)
                [~, input] = obj.predict_next_layer(input, layer_num);
            end
            target = input;
        end
        function train(obj, input, target, maxIter, theta)
            %����ѵ��BP����
            disp(sprintf('\n ѵ��BP��'));
            % ���� calc_cost_grad ���Ը��ݵ�ǰ����� cost �� gradient�����ǲ�����ȷ��
            % �������Mark Schmidt�İ����Ż����� ����������l-BFGS
            % Mark Schmidt (http://www.di.ens.fr/~mschmidt/Software/minFunc.html) [����ѧ��]
            addpath minFunc/
            option.Method = 'lbfgs';
            if exist('maxIter', 'var')
                option.maxIter = maxIter; % L-BFGS ������������
            else
                option.maxIter = 100;
            end
            option.display = 'on';
            % option.TolX = 1e-3;

            if exist('theta', 'var')
                obj.initialize_parameters(theta);
            end
            
            [obj.theta, ~] = minFunc(@(x) obj.calc_cost_grad(input, target, x), ...
                obj.theta, option);  
        end
        function accuracy = test(obj, input, target)
            %��������Ԥ���׼ȷ��
            result = obj.predict(input);
            if strcmp(obj.activations{end},'softmax') % ��ǩ�ྫ��
                % ��Ԥ��ĸ��ʾ����У�ÿ�������ʵ�ֵ��1��������0
                result = bsxfun(@eq, result, max(result));
                
                indexRow = target';
                indexCol = 1:length(indexRow);
                index    = (indexCol - 1) .* obj.architecture(end) + indexRow;
                
                accuracy = sum(result(index))/length(indexRow);
            else % ʵֵ�ྫ��
                accuracy = sum(sum((target - result).^2)) / (2 * size(target,2));
            end
        end
        function disp(obj)
            %��������������
            obj.description();
            
            nn_info = sprintf('-----------------------------------------------\n');
            nn_info = [nn_info, ...
                sprintf('%s !\n', ...
                ['��������� ' num2str(obj.layers) ' �㣺' num2str(obj.architecture)])];
            
            nn_activations = '';
            for i = 1:length(obj.activations)
                nn_activations = [nn_activations '  ' obj.activations{i}];
            end
            nn_info = [nn_info, ...
                sprintf('ÿ�㼤����ֱ�Ϊ��%s ~\n', nn_activations)];
            nn_info = [nn_info, ...
                sprintf('�������Ȩ��˥��Ȩ��Ϊ��%d ~\n', obj.options.decay_lambda)];
            nn_info = [nn_info, sprintf('-----------------------------------------------\n')];
            disp(nn_info);
        end
    end
    methods(Access = private)
        %��������ǰ�����ͺ������
        
        function [hidden_V, hidden_X]  = predict_next_layer(obj, input, layer_num)
            %�����������ز�layer_num����һ��� �յ��ֲ���hiddenV �� ���hiddenX
            addpath('.\activation_function');
            this_layer_size = obj.architecture(layer_num);
            next_layer_size = obj.architecture(layer_num + 1);
            start_index = (obj.architecture + 1) .* [obj.architecture(2:end) 0];
            start_index = cumsum(start_index([end 1:end-1])) + 1;
            
            start_index = start_index(layer_num);
            end_index   = start_index + next_layer_size * this_layer_size - 1;
            
            active_func = str2func(obj.activations{layer_num}); % �����
            % �õ� ϵ��w �� b��softmax��û�У�,������ �յ��ֲ��� �� ���
            w = reshape(obj.theta(start_index : end_index), next_layer_size, this_layer_size);
            if strcmp(obj.activations{layer_num}, 'softmax')
                hidden_V = w * input;
            else
                start_index = end_index + 1;
                end_index   = end_index + next_layer_size;
                b = obj.theta(start_index : end_index);
                hidden_V = bsxfun(@plus, w * input, b);
            end
            hidden_X = active_func(hidden_V);
        end
        function [cost, grad] = calc_cost_grad(obj, input, target, theta)
            %�����������ݶ�
            addpath('.\activation_function');
            
            samples_num = size(input, 2); % ������
            grad        = zeros(size(theta));
            % ��ʼ��һЩ�������յ��ֲ������ݡ����/��������
            hidden_V    = cell(1, obj.layers - 1);
            hidden_X    = cell(1, obj.layers);
            hidden_X{1} = input;
            cost        = 0;
            % feed-forward�׶�
            startIndex = 1; % �洢�������±����
            for i = 1:(obj.layers - 1)
                visibleSize = obj.architecture(i);
                hiddenSize  = obj.architecture(i + 1);
                
                activation_func = str2func(obj.activations{i}); % �� ������� תΪ �����
                
                % �Ƚ� theta ת��Ϊ (W, b) �ľ���/���� ��ʽ���Ա����������initializeParameters�ļ����Ӧ��
                endIndex   = hiddenSize * visibleSize + startIndex - 1; % �洢�������±��յ�
                W          = reshape(theta(startIndex : endIndex), hiddenSize, visibleSize);
                
                if strcmp(obj.activations{i}, 'softmax') % softmax��һ�㲻��ƫ��b
                    startIndex = endIndex + 1; % �洢�������±����
                    
                    hidden_V{i} = W * hidden_X{i};% ��� -> �õ��յ��ֲ��� V
                else
                    startIndex = endIndex + 1; % �洢�������±����
                    endIndex   = hiddenSize + startIndex - 1; % �洢�������±��յ�
                    b          = theta( startIndex : endIndex );
                    startIndex = endIndex + 1;
                    
                    hidden_V{i} = bsxfun(@plus, W * hidden_X{i}, b); % ��� -> �õ��յ��ֲ��� V
                end
                hidden_X{i + 1} = activation_func(hidden_V{i}); % �����
                % ����������ķ�����
                cost = cost + 0.5 * obj.options.decay_lambda * sum(sum(W .^ 2));
            end
            
            % ��cost function + regularization
            if strcmp(obj.activations{end}, 'softmax') % ��ǩ��cost
                % softmax��cost�����Ҳ�û������������Ҽ���1. ����ģ��׼ȷ��
                indexRow = target';
                indexCol = 1:samples_num;
                index    = (indexCol - 1) .* obj.architecture(end) + indexRow;
                cost = cost - sum(log(hidden_X{end}(index))) / samples_num;
            else % ʵֵ��cost
                cost = cost + sum( sum((target - hidden_X{end}).^2) ) ./ 2 / samples_num;
            end
            
            % Back Propagation �׶Σ���ʽ������
            % �����һ��
            activation_func_deriv = str2func([obj.activations{end}, '_derivative']);
            if strcmp(obj.activations{end}, 'softmax' ) % softmax��һ������Ҫ����labels��Ϣ
                dError_dHiddenV = activation_func_deriv(hidden_V{end}, target);
            else
                % dError/dOutputV = dError/dOutputX * dOutputX/dOutputV
                dError_dHiddenV = -( target - hidden_X{end} ) .* ...
                    activation_func_deriv( hidden_V{end} );
            end
            % dError/dW = dError/dOutputV * dOutputV/dW
            dError_dW   = dError_dHiddenV * hidden_X{obj.layers - 1}';
            
            end_index   = obj.parameters_num; % �洢�������±��յ�
            if strcmp( obj.activations{end}, 'softmax' ) % softmax��һ�㲻��ƫ��b
                start_index = end_index + 1; % �洢�������±����
            else
                % �����ݶ� b
                start_index = end_index - obj.architecture(end)  + 1; % �洢�������±����
                dError_db   = sum(dError_dHiddenV, 2);
                grad(start_index:end_index) = dError_db ./ samples_num;
            end
            % �����ݶ� W
            end_index   = start_index - 1; % �洢�������±��յ�
            start_index = end_index - obj.architecture(end - 1) * obj.architecture(end)  + 1; % �洢�������±����
            W           = reshape(theta(start_index:end_index), ...
                obj.architecture(end), obj.architecture(end - 1));
            WGrad       = dError_dW ./ samples_num + obj.options.decay_lambda * W;
            grad( start_index:end_index ) = WGrad(:);
            
            % ���ش� error back-propagation
            for i = (obj.layers - 2):-1:1
                activation_func_deriv = str2func([obj.activations{i}, '_derivative']);
                % dError/dHiddenV = dError/dHiddenX * dHiddenX/dHiddenV
                % dError/dHiddenX = dError/dOutputV * dOutputV/dHiddenX
                dError_dHiddenV = W' * dError_dHiddenV .* activation_func_deriv(hidden_V{i});
                % dError/dW1 = dError/dHiddenV * dHiddenV/dW1
                dError_dW = dError_dHiddenV * hidden_X{i}';
                
                dError_db = sum(dError_dHiddenV, 2);
                % �����ݶ� b
                end_index   = start_index - 1; % �洢�������±��յ�
                start_index = end_index - obj.architecture(i + 1)  + 1; % �洢�������±����
                % b           = theta(start_index : end_index);
                grad(start_index:end_index) = dError_db ./ samples_num;
                
                % �����ݶ� W
                end_index   = start_index - 1; % �洢�������±��յ�
                start_index = end_index - ...
                    obj.architecture(i) * obj.architecture(i + 1)  + 1; % �洢�������±����
                W           = reshape(theta(start_index:end_index), ...
                    obj.architecture(i + 1), obj.architecture(i) );
                WGrad       = dError_dW ./ samples_num + obj.options.decay_lambda * W;
                grad(start_index:end_index) = WGrad(:);
            end
        end
    end
    methods(Hidden, Access = private)
        %���ڳ�ʼ��
        
        function initialize_activations(obj, activations)
            %��ʼ������ļ���������б�
            if exist('activations', 'var')
                if ~isa(activations, 'cell')
                    error('������б� �����ǰ�Ԫ���飡');
                elseif length(activations) ~= obj.layers - 1
                    error('������б� �� ������� ��һ�£�');
                else
                    for i = 1:length(activations)
                        if isempty(activations{i})
                            activations{i} = 'Sigmoid';
                        else
                            flag = 0;
                            for j = 1:size(obj.activations_list, 1)
                                if strcmp(strtrim(obj.activations_list(j, :)), activations{i})
                                    flag = 1;
                                    break;
                                end
                            end
                            if flag == 0
                                error(['��������ô��� ' activations{i} ' �����ڣ�']);
                            end
                        end
                    end
                end
                obj.activations = activations;
            else
                obj.activations = cell(obj.layers - 1, 1);
                for i = 1:(obj.layers - 2)
                    obj.activations{i} = 'Sigmoid';
                end
                obj.activations{length(obj.activations)} = 'softmax';
            end
        end
        function initialize_options(obj, options)
            %��ʼ��BP����ѡ�� options
            % decay_lambda��  Ȩ��˥��ϵ�������������Ȩ��;
            if ~exist('options', 'var')
                options = [];
            end
            
            if isfield( options, 'decay_lambda' )
                obj.options.decay_lambda = options.decay_lambda;
            else
                obj.options.decay_lambda = 0.01;
            end
        end
        function initialize_parameters(obj, theta)
            %��ʼ���������
            if exist('theta', 'var')
                if length(theta) == obj.parameters_num
                    obj.theta = theta;
                else
                    error(['�����theta����ά�ȴ���Ӧ��Ϊ ' ...
                        num2str(obj.parameters_num) ' ά��']);
                end
            else
                % ���� Hugo Larochelle ����
                obj.theta = zeros(obj.parameters_num, 1);
                
                start_index = 1; % ����ÿ������w���±����
                for layer = 1:(obj.layers - 1) % layer  -> layer + 1
                    % ����ÿ������W���±��յ�
                    end_index = start_index + ...
                        obj.architecture(layer + 1) * obj.architecture(layer) - 1;
                    
                    r = sqrt( 6 ) / sqrt( obj.architecture(layer + 1) + obj.architecture(layer) );
                    obj.theta(start_index:end_index, 1) = ...
                        rand( obj.architecture(layer + 1) * obj.architecture(layer), 1 ) * 2 * r - r;
                    
                    % ������һ������W���±���㣨����b��
                    start_index = end_index + obj.architecture(layer + 1) + 1;
                end
            end
        end
    end
    methods(Static)
        function description()
            %�Ը��������͵�����
            disp_info = [sprintf('\n����һ��ȫ����BP�����磡\n'), ...
                sprintf('��������Ϊ��ǰ������������������ش�����������\n'),...
                sprintf('-�����ʼ���Ĳ���Ϊ�������� architecture��\n'),...
                sprintf('-��ѡ��ʼ���Ĳ���Ϊ��������б� activations������ѡ�� options��������� theta��\n'),...
                sprintf('\t ��ѡ�ļ����activations�У�Sigmoid, tanh, ReLU, leaky_ReLU, parameter_ReLU, softmax��\n'),...
                sprintf('\t ��ѡ�� ����ѡ��options �У�\n'),...
                sprintf('\t\t decay_lambda��     Ȩ��˥��ϵ�������������Ȩ�أ�Ĭ��Ϊ0.01��\n'), ...
                sprintf('\t Ĭ�ϳ�ʼ�� ������� theta ʹ�ã�Hugo Larochelle ���飬[-sqrt(6/h1/h2),sqrt(6/h1/h2)]��\n'),...
                sprintf('\n')];
            disp(disp_info);
        end
    end
end




