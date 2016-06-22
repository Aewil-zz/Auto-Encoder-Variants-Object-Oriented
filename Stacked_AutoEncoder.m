classdef Stacked_AutoEncoder < Feedforward_Neural_Network
    % һ��ȫ����ǰ��SAE����
    % by ֣��ΰ Aewil 2016-05
    % ����ṹ��������� ֻ�г�ʼ��ʱ����������Ҳ���ɸģ�����ѡ��ɸ�
    properties(SetAccess = private, GetAccess = public)
        %����ṹ
        architecture
        %ÿһ�㼤�������
        activations
        %SAE�������
        theta4SAE
        %ÿ��AE���� + ���һ��BP����Ĳ���
        theta4AEs
    end
    properties(SetAccess = public, GetAccess = public)
        %����ѡ��
        options
    end
    properties(Hidden, SetAccess = private, GetAccess = public)
        %��������
        parameters_num4SAE = 0;
        parameters_num4AEs = 0;
        %����
        layers             = 0;
    end
    properties(Hidden, Constant)
        %��ѡ������б�
        activations_list = char('Sigmoid', 'tanh',...
            'ReLU', 'leaky_ReLU', 'parameter_ReLU', 'softmax');
    end
    
    methods
        %ʵ������Ļ������ܣ���ʼ����ѵ����Ԥ�⡢���ԡ�չʾ
        
        function obj = Stacked_AutoEncoder(architecture, activations, options, theta4AEs)
            %���캯��
            % architecture & layers
            if isa(architecture, 'double')
                obj.architecture = architecture;
            else
                error('SAE����ṹ������һ�������б�!');
            end
            obj.layers = length(architecture);
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
            % parameters_num4SAE & parameters_num4AEs
            obj.parameters_num4SAE = sum((obj.architecture(1:end-1) + 1) .* obj.architecture(2:end));
            if strcmp(obj.activations{end}, 'softmax')
                obj.parameters_num4SAE = obj.parameters_num4SAE - obj.architecture(end);    
            end
            obj.parameters_num4AEs = sum((obj.architecture(1:end-1) + 1) .* obj.architecture(2:end)) + ...
                sum(obj.architecture(1:end-2) .* (obj.architecture(2:end-1) + 1));
            if strcmp(obj.activations{end}, 'softmax')
                obj.parameters_num4AEs = obj.parameters_num4AEs - obj.architecture(end);    
            end
            % theta4AEs & theta4SAE
            if exist('theta4AEs', 'var')
                obj.initialize_parameters(theta4AEs);
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
        function train(obj, input, target, maxIter4AE, maxIter4BP, theta4AEs)
            %����ѵ��SAE����
            if ~exist('maxIter4AE', 'var')
                maxIter4AE = 100;
            end
            if ~exist('maxIter4BP', 'var')
                maxIter4BP = 200;
            end
            if exist('theta4AEs', 'var')
                obj.initialize_parameters(theta4AEs); 
            end
            obj.pre_training(input, target, maxIter4AE);
            obj.fine_tune(input, target, maxIter4BP);
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
            w = reshape(obj.theta4SAE(start_index : end_index), next_layer_size, this_layer_size);
            if strcmp(obj.activations{layer_num}, 'softmax')
                hidden_V = w * input;
            else
                start_index = end_index + 1;
                end_index   = end_index + next_layer_size;
                b = obj.theta4SAE(start_index : end_index);
                hidden_V = bsxfun(@plus, w * input, b);
            end
            hidden_X = active_func(hidden_V);
        end
        function pre_training(obj, input, target, maxIter4AE)
            %��SAE����Ԥѵ����ѵ�� ���AE �� һ��BP
            
            % layer-wise ѵ��AE
            input4AE     = input;
            option4AE    = obj.options; % AE�����ѡ��
            weight_start = 1; % weighted-cost�����У����±����
            weight_end   = 0; % weighted-cost�����У����±��յ�
            
            start_index4AEs = 1; % AE����������±����
            end_index4AEs   = 0; % AE����������±��յ�
            for layer = 1:(obj.layers-2)
                % ����ÿ��AE��weight_end������Ҫ��
                if obj.options.is_weighted_cost
                    weight_end = weight_end + obj.architecture(layer);
                    option4AE.weighted_cost = ...
                        obj.options.weighted_cost(weight_start:weight_end);
                    weight_start = weight_end + 1;
                end
                % ���ò����±��յ�
                end_index4AEs = end_index4AEs + ...
                    2 * obj.architecture(layer) * obj.architecture(layer + 1) + ...
                    obj.architecture(layer) + obj.architecture(layer + 1);
                % ���� AE����Ľṹ �� �����
                architecture4AE = [obj.architecture(layer), obj.architecture(layer + 1), ...
                    obj.architecture(layer)];
                activations4AE = {obj.activations{layer}, obj.activations{layer}};
                
                % ����AE��������ѵ��
                if option4AE.is_denoising && ...
                        strcmp(option4AE.noising_layer, 'first_layer') && ...
                        layer ~= 1
                    option4AE.is_denoising = 0;
                end
                if sum(obj.theta4AEs(start_index4AEs:end_index4AEs)) ~= 0
                    Autoencoder = AutoEncoder(architecture4AE, activations4AE, ...
                        option4AE, obj.theta4AEs(start_index4AEs:end_index4AEs));
                else
                    Autoencoder = AutoEncoder(architecture4AE, activations4AE, option4AE);
                end
                Autoencoder.train(input4AE, maxIter4AE);
                input4AE = Autoencoder.encode(input4AE);
                % ���AE�Ĳ���
                obj.theta4AEs(start_index4AEs:end_index4AEs) = Autoencoder.theta;
                % ���ò����±���ʵ��
                start_index4AEs = end_index4AEs + 1;
            end
            
            
            % ���һ��BP��ѵ��
            architecture4BP = [obj.architecture(end - 1), obj.architecture(end)];
            activations4BP  = obj.activations(end);
            if sum(obj.theta4AEs(start_index4AEs:end)) ~= 0
                Backpropagation = BackPropagation(architecture4BP, activations4BP, ...
                    obj.options, obj.theta4AEs(start_index4AEs:end));
            else
                Backpropagation = BackPropagation(architecture4BP, activations4BP, obj.options);
            end
            Backpropagation.train(input4AE, target, maxIter4AE);
            obj.theta4AEs(start_index4AEs:end) = Backpropagation.theta;
            
            %�� AEs �Ĳ��ֲ�����ֵ�� SAE
            obj.theta4AEs_to_theta4SAE();
        end
        function fine_tune(obj, input, target, maxIter4BP)
            %��SAE��������΢��
            Backpropagation = BackPropagation(obj.architecture, obj.activations, ...
                    obj.options, obj.theta4SAE);
            Backpropagation.train(input, target, maxIter4BP);
            obj.theta4SAE = Backpropagation.theta;
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
            % noising_layer:     �������������㣺first_layer or all_layers
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
                    % ���������������
                    if isfield(options, 'noising_layer')
                        obj.options.noising_layer = options.noising_layer;
                    else
                        obj.options.noising_layer = 'first_layer';
                    end
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
                if isfield(options, 'weighted_cost') && ~isempty(options.weighted_cost)
                    obj.options.weighted_cost = options.weighted_cost;
                else
                    obj.options.weighted_cost = rand(sum(obj.architecture(1:end-2)), 1) * 2;
                end
            end
        end
        function initialize_parameters(obj, theta4AEs)
            %��ʼ���������
            
            obj.theta4SAE = zeros(obj.parameters_num4SAE, 1);
            if exist('theta4AEs', 'var')
                if length(theta4AEs) == obj.parameters_num4AEs
                    obj.theta4AEs = theta4AEs;
                    % �� AEs �Ĳ��ֲ�����ֵ�� SAE
                    obj.theta4AEs_to_theta4SAE();
                else
                    error(['�����theta����ά�ȴ���Ӧ��Ϊ ' ...
                        num2str(obj.parameters_num4AEs) ' ά��']);
                end
            else
                % ֱ�ӳ�ʼ��Ϊ0������Ϊ����AE�࣬AE������г�ʼ��
                obj.theta4AEs = zeros(obj.parameters_num4AEs, 1);
            end
        end
        function theta4AEs_to_theta4SAE(obj)
            %�� AEs �Ĳ��ֲ�����ֵ�� SAE
            start_index4SAE = 1;
            start_index4AEs = 1;
            for layer = 1:(obj.layers - 2)
                end_index4SAE = start_index4SAE - 1 + ...
                    (obj.architecture(layer) + 1) * obj.architecture(layer + 1);
                end_index4AEs = start_index4AEs - 1 + ...
                    (obj.architecture(layer) + 1) * obj.architecture(layer + 1);
                
                obj.theta4SAE(start_index4SAE:end_index4SAE) = ...
                    obj.theta4AEs(start_index4AEs:end_index4AEs);
                
                start_index4SAE = end_index4SAE + 1;
                start_index4AEs = end_index4AEs + ...
                    obj.architecture(layer) * (obj.architecture(layer + 1) + 1) + 1;
            end
            obj.theta4SAE(start_index4SAE:end) = ...
                obj.theta4AEs(start_index4AEs:end);
        end
    end
    methods(Static)
        function description()
            %�Ը��������͵�����
            disp_info = [sprintf('\n����һ��ȫ����ջʽ�Ա����� Stacked Auto-Encoder��\n'), ...
                sprintf('��������Ϊ��������AEʵ��Ԥѵ���������BP΢����\n'),...
                sprintf('-�����ʼ���Ĳ���Ϊ�������� architecture��\n'),...
                sprintf('-��ѡ��ʼ���Ĳ���Ϊ��������б� activations������ѡ�� options��������� theta��\n'),...
                sprintf('\t ��ѡ�ļ����activations�У�Sigmoid, tanh, ReLU, leaky_ReLU, parameter_ReLU��softmax��\n'),...
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
                sprintf('\t\t\t weighted_cost����Ȩcost��Ȩ�ء�;\n'),...
                sprintf('\n')];
            disp(disp_info);
        end
    end
end