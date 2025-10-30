function [recog_rate, ll, varargout]=recognition_Viterbi_hmm_skips_1gau(testinglist_filename,model_filename,feature_file_format)
if nargin < 1,  testinglist_filename='testing_list10.mat';  end;
if nargin < 2,  model_filename='models.mat'; end;
if nargin < 3,  feature_file_format='no-head'; end;

load(testinglist_filename, 'list');
load(model_filename, 'mean_vec_i_m', 'var_vec_i_m', 'a_i_j_m');

[dim,N,MODEL_NO]=size(mean_vec_i_m);
correct_count=0;
error_count=0;
   
utterance_no=size(list,1);
ll = zeros(1,utterance_no);
for k=1:utterance_no
        filename=list{k,2};
        fid=fopen(filename,'r');
        if strcmpi(feature_file_format, 'HTK')
           fseek(fid, 12, 'bof'); % skip the 12-byte HTK header
        end
        c=fread(fid,'float','b');        
        fclose(fid);
        fr_no=length(c)/dim;
        c=reshape(c,dim,fr_no);
        scores=ones(MODEL_NO,1)*(-inf);
        for m=1:MODEL_NO
            scores(m)=viterbi_hmm_LR_skips_1gau( c, mean_vec_i_m(:,:,m), var_vec_i_m(:,:,m), a_i_j_m(:,:,m) );
        end
        [ll(k), m_max]=max(scores);
        %fprintf('word= %d   recog=%d \n',list{k,1},m_max);  
        if (m_max==list{k,1}) 
            correct_count=correct_count+1;
        else 
            error_count=error_count+1;
        end
end

total_count=(error_count+correct_count);
recog_rate=correct_count/total_count;
if nargout > 1
    varargout(1)= { total_count };
end

fprintf('recognition rate =%5.2f  error count =%d   correct count =%d  total_count=%d \n',recog_rate*100,error_count, correct_count, total_count);
