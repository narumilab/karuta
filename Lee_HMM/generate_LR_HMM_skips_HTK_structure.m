function generate_LR_HMM_skips_HTK_structure(model_filename,model_id,VecSize,parmKind,aug_state_no,A0,Aij,Af)
if nargin==0
    model_filename='temp_hmm.txt'; model_id='temp_hmm';
    VecSize =39;parmKind='mfcc_e_d_a';
    aug_state_no=10; A0=[0.8 0.2]; Aij=[0.6 0.3 0.1]; 
    Af=[];
    % Af(k)=transition probability from the last k-th emit-state to the null end state.
    % provided that Af(k) > A(aug_state_no-k,aug_state_no)
end
N=aug_state_no; % the number of states including the start and end dummy states
fid=fopen(model_filename,'w');
fprintf(fid,'  ~o <VecSize> %d <%s> <StreamInfo> %d %d\n',VecSize,parmKind,1,VecSize);
fprintf(fid,'  ~h "%s"\n',model_id);
fprintf(fid,'<BeginHMM>\n');
fprintf(fid,'  <NumStates> %d\n',N);
for s=2:N-1
    fprintf(fid,'  <State> %d <NumMixes> 1\n',s);
    fprintf(fid,'  <Stream> 1\n');
    fprintf(fid,'  <Mixture> 1 1.0000\n');
    fprintf(fid,'    <Mean> %d\n',VecSize);
    fprintf(fid,'      ');
    for k=1:VecSize; fprintf(fid,'0.0 '); end;fprintf(fid,'\n');
    fprintf(fid,'    <Variance> %d\n',VecSize);
    fprintf(fid,'      ');
    for k=1:VecSize; fprintf(fid,'1.0 '); end;fprintf(fid,'\n');
end

fprintf(fid,'  <TransP> %d \n',N);
A=zeros(N,N);
A(1,1)=0; A(1,2:length(A0)+1)=A0;
for i=2:N-length(Aij)+1
    A(i,1:i-1)=0;
    A(i,i:i+length(Aij)-1) = Aij;
end

for i=N-length(Aij)+2:N
    A(i,1:i-1)=0;
    A(i,i:N) = Aij(1:N-i+1)/sum(Aij(1:N-i+1));
end

for k=1:length(Af)
    row=N-k;
    if A(row,N) < Af(k)
        A(row,1:N-1)=A(row,1:N-1)/(1-A(row,N))*(1-Af(k));
        A(row,N)=Af(k);
    end
end

for i=1:N
    fprintf(fid,'   %11.4e',A(i,:));
    fprintf(fid,'\n');
end

fprintf(fid,' <ENDHMM>\n');
fclose(fid);

