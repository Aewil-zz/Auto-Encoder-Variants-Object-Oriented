function y = leaky_ReLU(x, alpha) % ��ģ�黹û��ɣ��̶���alpha
    y = max(alpha * x, x);
end