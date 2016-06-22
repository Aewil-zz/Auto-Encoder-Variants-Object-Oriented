function KLDeriv = getKL_deriv(sparse_rho,rho_hat)
%KL-ɢ�Ⱥ����ĵ���
    EPSILON = 1e-8; %��ֹ��0
    KLDeriv = ( -sparse_rho ) ./ ( rho_hat + EPSILON ) + ...
        ( 1 - sparse_rho ) ./ ( 1 - rho_hat + EPSILON );  
end