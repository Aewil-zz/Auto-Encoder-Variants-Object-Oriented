classdef (Abstract) Feedforward_Neural_Network < handle
    %һ��ȫ����ǰ�������������
    
    methods
        %ǰ��������
        target = predict(obj, input)
        %����ѵ������
        train(obj, input, target, option, theta)
    end
    
    methods(Static)
        function description()
            %�Ը��������͵�����
            disp_info = [sprintf('\n����һ��ȫ����ǰ��������!\n'), ...
                sprintf('Ŀǰ����һ�������...\n')];
            disp(disp_info);
        end
    end
end