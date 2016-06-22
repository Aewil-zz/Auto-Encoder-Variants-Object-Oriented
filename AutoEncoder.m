classdef AutoEncoder < Feedforward_Neural_Network
    % һ��ȫ����ǰ��AE����
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
    end
    properties(Hidden, Constant)
        %����
        layers           = 3;
        %��ѡ������б�
        activations_list = char('Sigmoid', 'tanh',...
            'ReLU', 'leaky_ReLU', 'parameter_ReLU');
    end
    
    methods
        %ʵ������Ļ������ܣ���ʼ����ѵ����Ԥ�⡢���ԡ��õ��м�㡢չʾ
        
        function obj = AutoEncoder(architecture, activations, options, theta)
            %���캯��
            % archietecture
            if isa(architecture, 'double') && length(architecture) == obj.layers
                obj.architecture = architecture;
            else
                error('AE����ṹ������һ�������б����ҽṹΪ3��!');
            end
            % activations
            if exist('activations', 'var')
                obj.initialize_activations(activations);
            else
                obj.initialize_activations();
            end
            % options
            if exist('options', 'var')
                obj.initialize_options(options);
            else
                obj.initialize_options();
            end
            % parameters_num & theta
            obj.parameters_num = sum((obj.architecture(1:end-1) + 1) .* obj.architecture(2:end));
            
            if exist('theta', 'var')
                obj.initialize_parameters(theta);
            else
                obj.initialize_parameters();
            end
        end
        function train(obj, input, maxIter, theta)
            %����ѵ��BP����
            disp(sprintf('\n ѵ��AE��'));
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
            
            % �жϸ� countAE�� AE�Ƿ���Ҫ���noise �� ʹ��denoising����
            [ is_denoising, corrupted_input ] = obj.denoising_switch(input);
            if is_denoising
                [obj.theta, ~] = minFunc(@(x) obj.calc_cost_grad(input, x, corrupted_input), ...
                    obj.theta, option);
            else
                [obj.theta, ~] = minFunc(@(x) obj.calc_cost_grad(input, x), ...
                    obj.theta, option);
            end
        end
        function target   = predict(obj, input)
            %ǰ��������
            target = input;
            for layer_num = 1:(obj.layers - 1)
                [~, target] = obj.predict_next_layer(target, layer_num);
            end
        end
        function accuracy = test(obj, input)
            %��������Ԥ���׼ȷ��
            result = obj.predict(input);
            accuracy = sum(sum((input - result).^2)) / (2 * size(input,2));
        end
        function code     = encode(obj, input)
            %�õ�AE������м���ʾ
            [~, code] = obj.predict_next_layer(input, 1);
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
            active_func = str2func(obj.activations{layer_num}); % �����
            
            start_index = (obj.architecture + 1) .* [obj.architecture(2:end) 0];
            start_index = cumsum(start_index([end 1:end-1])) + 1;
            
            start_index = start_index(layer_num);
            end_index   = start_index + next_layer_size * this_layer_size - 1;
            
            % �õ� ϵ��w �� b��softmax��û�У�,������ �յ��ֲ��� �� ���
            w = reshape(obj.theta(start_index : end_index), next_layer_size, this_layer_size);
            
            start_index = end_index + 1;
            end_index   = end_index + next_layer_size;
            b = obj.theta(start_index : end_index);
            
            hidden_V = bsxfun(@plus, w * input, b);
            hidden_X = active_func(hidden_V);
        end
        function [cost, grad] = calc_cost_grad(obj, input, theta, corrupted_input)
            %�����������ݶ�
            addpath('.\activation_function');
            
            samples_num = size(input, 2); % ������
            visibleSize = obj.architecture(1);
            hiddenSize  = obj.architecture(2);
            
            W1 = reshape(theta(1:(hiddenSize * visibleSize)), ...
                hiddenSize, visibleSize);
            b1 = theta((hiddenSize * visibleSize + 1):(hiddenSize * visibleSize + hiddenSize));
            W2 = reshape(theta((hiddenSize * visibleSize + hiddenSize + 1):(2 * hiddenSize * visibleSize + hiddenSize)), ...
                visibleSize, hiddenSize);
            b2 = theta((2 * hiddenSize * visibleSize + hiddenSize + 1) : end);
            
            cost = 0;
            % feed-forward�׶�
            activation_func = str2func(obj.activations{1}); % �� ������� תΪ �����
            if exist('corrupted_input', 'var')
                hidden_V = bsxfun(@plus, W1 * corrupted_input, b1);
            else
                hidden_V = bsxfun(@plus, W1 * input, b1);
            end
            hidden_X = activation_func(hidden_V);
            % sparse
            if obj.options.is_sparse
                rho_hat = sum(hidden_X, 2) / samples_num;
                KL = getKL( obj.options.sparse_rho, rho_hat);
                cost = cost + obj.options.sparse_beta * sum(KL);
            end
            
            activation_func = str2func(obj.activations{2});
            output_V = bsxfun(@plus, W2 * hidden_X, b2);
            output_X = activation_func(output_V);
            
            if obj.options.is_weighted_cost
                cost = cost + sum(obj.options.weighted_cost' * (output_X - input).^2) / samples_num / 2;
            else
                cost = cost + sum(sum((output_X - input) .^ 2)) / samples_num / 2;
            end
            cost = cost + obj.options.decay_lambda * (sum(sum(W1 .^ 2)) + sum(sum(W2 .^ 2))) / 2;
            % Back Propagation �׶Σ���ʽ������
            activation_func_deriv = str2func([obj.activations{1}, '_derivative'] );
            % ��ʽ������
            % dError/dOutputV = dError/dOutputX * dOutputX/dOutputV
            if obj.options.is_weighted_cost
                dError_dOutputV   = bsxfun(@times, -(input - output_X), obj.options.weighted_cost) .* ...
                    activation_func_deriv(output_V);
            else
                dError_dOutputV   = -(input - output_X) .* activation_func_deriv(output_V);
            end
            
            % dError/dW2 = dError/dOutputV * dOutputV/dW2
            dError_dW2   = dError_dOutputV * hidden_X';
            
            W2Grad       = dError_dW2 ./ samples_num + obj.options.decay_lambda * W2;
            % dError/dHiddenV = ( dError/dHiddenX + dSparse/dHiddenX ) * dHiddenX/dHiddenV
            dError_dHiddenX   = W2' * dError_dOutputV; % = dError/dOutputV * dOutputV/dHiddenX
            dHiddenX_dHiddenV = activation_func_deriv(hidden_V);
            if obj.options.is_sparse
                dSparse_dHiddenX = obj.options.sparse_beta .* getKL_deriv( obj.options.sparse_rho, rho_hat );
                dError_dHiddenV  = (dError_dHiddenX + repmat(dSparse_dHiddenX, 1, samples_num)) .* dHiddenX_dHiddenV;
            else
                dError_dHiddenV  = dError_dHiddenX .* dHiddenX_dHiddenV;
            end
            % dError/dW1 = dError/dHiddenV * dHiddenV/dW1
            dHiddenV_dW1 = input';
            dError_dW1   = dError_dHiddenV * dHiddenV_dW1;
            W1Grad       = dError_dW1 ./ samples_num + obj.options.decay_lambda * W1;
            
            % ��ƫ�õĵ���
            dError_db2 = sum(dError_dOutputV, 2);
            b2Grad     = dError_db2 ./ samples_num;
            dError_db1 = sum(dError_dHiddenV, 2);
            b1Grad     = dError_db1 ./ samples_num;
            
            grad = [ W1Grad(:); b1Grad(:); W2Grad(:); b2Grad(:) ];
        end
        function [is_denoising, corrupted_input ] = denoising_switch(obj, input)
            %�жϸò�AE�Ƿ���Ҫ���noise��ʹ��denoising����
            % ���� �Ƿ�is_denoising�ı�־ �� �������ź�
            
            % is_denoising��	�Ƿ�ʹ�� denoising ����
            % noise_rate��	ÿһλ��������ĸ���
            % noise_mode��	���������ģʽ��'on_off' or 'Guass'
            % noise_mean��	��˹ģʽ����ֵ
            % noise_sigma��	��˹ģʽ����׼��
            
            is_denoising    = 0;
            corrupted_input = [];
            if obj.options.is_denoising
                is_denoising = 1;
                corrupted_input = input;
                indexCorrupted = rand(size(input)) < obj.options.noise_rate;
                switch obj.options.noise_mode
                    case 'Guass'
                        % ��ֵΪ noiseMean����׼��Ϊ noiseSigma �ĸ�˹����
                        noise = obj.options.noise_mean + ...
                            randn(size(input)) * obj.options.noise_sigma;
                        noise(~indexCorrupted) = 0;
                        corrupted_input = corrupted_input + noise;
                    case 'OnOff'
                        corrupted_input(indexCorrupted) = 0;
                end
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
                for i = 1:(obj.layers - 1)
                    obj.activations{i} = 'Sigmoid';
                end
            end
        end
        function initialize_options(obj, options)
            %��ʼ��AE����ѡ�� options
            % decay_lambda��     Ȩ��˥��ϵ�������������Ȩ��
            
            % is_sparse��        �Ƿ�ʹ�� sparse hidden level �Ĺ���
            % sparse_rho��       ϡ������rho��
            % sparse_beta��      ϡ���Է���Ȩ�أ�
            
            % is_denoising��     �Ƿ�ʹ�� denoising ����
            % noise_rate��       ÿһλ��������ĸ���
            % noise_mode��       ���������ģʽ��'on_off' or 'Guass'
            % noise_mean��       ��˹ģʽ����ֵ
            % noise_sigma��      ��˹ģʽ����׼��
            
            % is_weighted_cost�� �Ƿ��ÿһλ���ݵ�cost���м�Ȩ�Դ�
            % weighted_cost��    ��Ȩcost��Ȩ��
            
            if ~exist('options', 'var')
                options = [];
            end
            % decay
            if isfield(options, 'decay_lambda')
                obj.options.decay_lambda = options.decay_lambda;
            else
                obj.options.decay_lambda = 0.01;
            end
            % sparse
            if isfield(options, 'is_sparse')
                obj.options.is_sparse = options.is_sparse;
            else
                obj.options.is_sparse = 0;
            end
            if obj.options.is_sparse
                if isfield(options, 'sparse_rho')
                    obj.options.sparse_rho = options.sparse_rho;
                else
                    obj.options.sparse_rho = 0.01;
                end
                if isfield(options, 'sparse_beta')
                    obj.options.sparse_beta = options.sparse_beta;
                else
                    obj.options.sparse_beta = 0.3;
                end
            end
            
            % de-noising
            if isfield(options, 'is_denoising')
                obj.options.is_denoising = options.is_denoising;
                if options.is_denoising
                    % ����ģʽ����˹ �� ����
                    if isfield(options, 'noise_mode')
                        obj.options.noise_mode = options.noise_mode;
                    else
                        obj.options.noise_mode = 'on_off';
                    end
                    switch options.noise_mode
                        case 'Guass'
                            if isfield(options, 'noise_mean')
                                obj.options.noise_mean = options.noise_mean;
                            else
                                obj.options.noise_mean = 0;
                            end
                            if isfield(options, 'noise_sigma')
                                obj.options.noise_sigma = options.noise_sigma;
                            else
                                obj.options.noise_sigma = 0.01;
                            end
                        case 'on_off'
                            % ��������
                            if isfield(options, 'noise_rate')
                                obj.options.noise_rate = options.noise_rate;
                            else
                                obj.options.noise_rate = 0.15;
                            end
                    end
                end
            else
                obj.options.is_denoising = 0;
            end
            
            % weightedCost
            if isfield(options, 'is_weighted_cost')
                obj.options.is_weighted_cost = options.is_weighted_cost;
            else
                obj.options.is_weighted_cost = 0;
            end
            if obj.options.is_weighted_cost
                if isfield(options, 'weighted_cost')
                    obj.options.weighted_cost = options.weighted_cost;
                else
                    error('��Ȩcostһ��Ҫ�Լ�����Ȩ��������');
                end
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
                    
                    r = sqrt(6 / (obj.architecture(layer + 1) + obj.architecture(layer)));
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
            disp_info = [sprintf('\n����һ��ȫ�����Ա����� Auto-Encoder��\n'), ...
                sprintf('��������Ϊ������back-propagationʵ�������������3�� fully-connected feedforward neural networks��\n'),...
                sprintf('\t\t   �Ӷ�ʵ�� encode & decode ���̡�\n\n'),...
                sprintf('-�����ʼ���Ĳ���Ϊ�������� architecture��\n'),...
                sprintf('-��ѡ��ʼ���Ĳ���Ϊ��������б� activations������ѡ�� options��������� theta��\n'),...
                sprintf('\t ��ѡ�ļ����activations�У�Sigmoid, tanh, ReLU, leaky_ReLU, parameter_ReLU��\n'),...
                sprintf('\t ��ѡ�� ����ѡ��options �У�\n'),...
                sprintf('\t\t decay_lambda��     Ȩ��˥��ϵ�������������Ȩ�أ�Ĭ��Ϊ0.01��\n'),...
                sprintf('\t\t is_sparse��        �Ƿ�ʹ�� sparse hidden level �Ĺ���Ĭ�ϲ�ʹ�ã�\n'),...
                sprintf('\t\t\t sparse_rho��   ϡ������rho��Ĭ��Ϊ0.01��\n'),...
                sprintf('\t\t\t sparse_beta��  ϡ���Է���Ȩ�أ�Ĭ��Ϊ0.3��\n'),...
                sprintf('\t\t is_denoising��     �Ƿ�ʹ�� denoising ����Ĭ�ϲ�ʹ��;\n'),...
                sprintf('\t\t\t noise_rate��   ÿһλ��������ĸ��ʣ�Ĭ��Ϊ0.15;\n'),...
                sprintf('\t\t\t noise_mode��   ���������ģʽ��"on_off" or "Guass"��Ĭ��Ϊon_off;\n'),...
                sprintf('\t\t\t noise_mean��   ��˹ģʽ����ֵ��Ĭ��Ϊ0;\n'),...
                sprintf('\t\t\t noise_sigma��  ��˹ģʽ����׼�Ĭ��Ϊ0.01;\n'),...
                sprintf('\t\t is_weighted_cost�� �Ƿ��ÿһλ���ݵ�cost���м�Ȩ�Դ���Ĭ�ϲ�ʹ��;\n'),...
                sprintf('\t\t\t weighted_cost����Ȩcost��Ȩ�ء�\n'),...
                sprintf('\t Ĭ�ϳ�ʼ�� ������� theta ʹ�ã�Hugo Larochelle ���飬[-sqrt(6/h1/h2),sqrt(6/h1/h2)]��\n'),...
                sprintf('\n')];
            disp(disp_info);
        end
    end
end






