�&r!� �"�s�	�!��5�!�������	�%�!��5�!������
�%�!�
��f�
 f��� f����f�
 f��!���J�!�	���/#�t���	�!�^�>����޴H�!s���	�!�C��� @��� ��s���	�!�%����� tL�1��1s̜�  tP� �X�f����������f��
�1��1s̜�  tP� �X�� �t���f3ҍ9�	�!� � �f�@�!�  �f�<�!s̣� ��r�@�!s̴>�!s̰�f�=�!s̣� �r�@�!s̃�>�!rJ��!�&�� �f�=�!s̣� ��r�?�!s̴>�!s̍6r�>r� �t� ��0��>t$�> u��>t��>t��>7�t#f�����$��1s̜�  tP� �X��>8�t"�����$��1s̜�  tP� �X��!� �1s̜�  tP� �X������!� ����1s̜�  tP� �X�� t#f�����1��1s̜�  tP� �X��6�L�!f�>� t����%�!f��    f�>� t����%�!f��    ���L�!PSQfR�$��1s̜�  tP� �X�f���������>7 u&��f���$��1s̜�  tP� �X�� �>7u&��f���$��1s̜�  tP� �X�� �>7u&��f���$��1s̜�  tP� �X�� �>7u&��f���$��1s̜�  tP� �X�� �>7u!��f���$��1s̜�  tP� �X��>7u!��f���$��1s̜�  tP� �X��� t�  t�>8u�� fZY[X�PSQR�$� �1s̜�  tP� �X������>8 u'� �\	�$��1s̜�  tP� �X��@�>8u'� �b	�$��1s̜�  tP� �X��@�>8u'� �h	�$��1s̜�  tP� �X��@�>8u'� �n	�$��1s̜�  tP� �X��@�>8u"� �t	�$��1s̜�  tP� �X��>8u"� �|	�$��1s̜�  tP� �X��� t�@ t�>7u� ZY[X�Ü��LuPR.�"���!�%�!ZX�.�.�PRV.�"�>7u� u�6�1�6��>8u�� u�6B��6��>7�t$� u� u�@ u�6��� �6��>8�t$� u� u�  u�6��� �6��>t�>u�
 u"�6i� �6���
 t�6�� �6��<�u�:t&�6�m �6���y �69�[ ��l �6��N f�>� t����%�!f��    f�>� t����%�!f��    �>6�t�M�!^ZX.�.�PV��<$t�UVW�_^]��^X�V< �6Wt)<�6^t!<�6dt<�6jt<�6ot	<�6ot���^���� .� @uf����.� @uf����.� @uf����.� @uf���.� @uf.�.�.�.��mfUf��fP.�� @u+f�/	gf�Ef����g�E��fXf]f.�.��lf.�.��T	�F���ȇF��fXf].�.��G.�.��%� �����������.�.��U��P.�"��	�F���ȇF� X].�.��.�.��.� tI��uDQVW.�"�6r��� ��_^Yu).�>u.�> t.�"���f��g�L$ϝ.�.��.� tQ��t��t�� t��u=�.�"�
�f�.�> u�f��g�d$��f�.�"��f��g�L$@ϝ.�.�PfR.�� f3ҍ2�	�!fZX�PR.�"� �G�	�!ZX�PfR.�� f3ҍ\�	�!fZX�PR.�"�� �x�	�!ZX�.�>$ u.PQfRW.��$� �>� f3ҍ��	�!�$_fZYX.� @uf.�.�.�.�PQfRW� �/�tL<tH<�tD� �ģ�*�>~� �W �*�
�u��0��0�
�>�� � f3ҍ_�	�!_fZYX�PSRQ�O�
 +����0�O��YIG�=0u� ��Z[X�fPSQfRW�&f��Q��f��Yf����$׈G��_fZY[fX�PSQRV�6� ��<�I</u+F���<?t*<d�<e�<pt&<s�<t�<v�� ���	�!���	�!���<=u�F�|,0r�<w�F�7�>8�t)��*���&87�� ��G�	�!�7�㋗��	�!���t�Ǉ'��G��<=�v�F�,0�l�<�f�F�8�>7�t)�������&78�� ��G�	�!�8�㋗L�	�!�����Ǉ������ �����  ���� @��� ���>7�u�>8�u��	�!���	�!�Z���	�!�>8�u�7��u�㋗|�	�!�2�>7�u�8����㋗��	�!���6��6���	�!��^ZY[Xì< t�<	t�N�<Ar<Zw �                                                              ��    d                        0123456789ABCDEF���Signalling a Critical Error by opening file $TEST24.TST 
TEST24   -- Version 2.01 -- A DPMI Critical Error Test Program
   (C) Copyright 1992-3 Sudley Place Software.
$��> Syntax error on command line.

$No handlers installed.
$PM handler called.
$VM handler called.
$PM CALLF return occurred.
$VM CALLF return occurred.
$��> INT 24h handler installed before VM->PM switch has been called...
$��> PM call did not happen.
$��> VM call did not happen.
$��> PM CALLF return did not happen.
$��> VM CALLF return did not happen.
$��> CHAIN to DOS did not happen but should have.
$��> CHAIN to DOS did happen but shouldn't.
$Syntax:  TEST24 [options]

where options consists zero or more of

/D   Debug mode
/E   Pause on error
/P=n where n=0 (IGNORE), 1 (RETRY), 2 (ABORT), 3 (FAIL), 4 (JMPF), 5 (CALLF)
     for PM INT 24h setting
/V=n where n=0 (IGNORE), 1 (RETRY), 2 (ABORT), 3 (FAIL), 4 (JMPF), 5 (CALLF)
     for VM INT 24h setting
/S   Enter PM as small (16-bit) DPMI client
/T   Display INT 31h trace output
$Running under Enhanced Windows x.xx
$No DPMI support available
$DPMI Enter Protected Mode call failed
$Allocation of Host Private Data failed
$DPMI function # ____h.
$�PM handler will IGNORE$PM handler will RETRY$PM handler will ABORT$PM handler will FAIL$PM handler will CHAIN via JMPF$PM handler will CHAIN via CALLF$$:Pe�VM handler will IGNORE$VM handler will RETRY$VM handler will ABORT$VM handler will FAIL$VM handler will CHAIN via JMPF$VM handler will CHAIN via CALLF$ -- $����'��> Program should terminate <��
$��> Critical Error should be IGNORE <��
$��> Critical Error should be RETRY <��
$��> Critical Error should be FAIL <��
$��> Critical Error should be CHAIN <��
$��> Unexpected action:  $ expected, actual action was $IGNORE$RETRY$ABORT$FAIL$CHAIN$  {�X��� {�X���        {�X�{{{�X���{�X�XX{�X���{�X���{�X���        {�X�{{{�X���{�X�XX{�X���{�X���{�X���IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  