function plot_results_hmm()
STATE_NO_RANGE=6:9;
ITERATION_BEGIN=1;
ITERATION_END=10;
ITERATION_RANGE=ITERATION_BEGIN:ITERATION_END

error_rate_EM_forward=zeros(ITERATION_END,max(STATE_NO_RANGE));
error_rate_EM_Viterbi=zeros(ITERATION_END,max(STATE_NO_RANGE));
error_rate_Viterbi_forward=zeros(ITERATION_END,max(STATE_NO_RANGE));
error_rate_Viterbi_Viterbi=zeros(ITERATION_END,max(STATE_NO_RANGE));
for state_no = STATE_NO_RANGE
        recog_rate_EM_forward=zeros(1,ITERATION_END);        
        recog_rate_EM_Viterbi=zeros(1,ITERATION_END);
        recog_rate_Viterbi_forward=zeros(1,ITERATION_END);
        recog_rate_Viterbi_Viterbi=zeros(1,ITERATION_END);
        EM_accuracy_filename=sprintf('recog_rate_S%d_EM_models.mat',state_no);
        Viterbi_accuracy_filename=sprintf('recog_rate_S%d_Viterbi_models.mat',state_no);        
        if ( exist(EM_accuracy_filename,'file')  )
            load(EM_accuracy_filename,'recog_rate_EM_forward','recog_rate_EM_Viterbi');
            error_rate_EM_forward(:,state_no)= (1-recog_rate_EM_forward')*100;
            error_rate_EM_Viterbi(:,state_no)= (1-recog_rate_EM_Viterbi')*100;        
        end
        if ( exist(Viterbi_accuracy_filename,'file')  )
            load(Viterbi_accuracy_filename,'recog_rate_Viterbi_Viterbi','recog_rate_Viterbi_forward');
            error_rate_Viterbi_forward(:,state_no)= (1-recog_rate_Viterbi_forward')*100;
            error_rate_Viterbi_Viterbi(:,state_no)= (1-recog_rate_Viterbi_Viterbi')*100;
        end    
end

% my_plot(ITERATION_RANGE,STATE_NO_RANGE,error_rate_EM_forward,'EM','Forward'); pause;
% ylim([0.33 0.62]);

 my_plot(ITERATION_RANGE,STATE_NO_RANGE,error_rate_EM_Viterbi,'EM','Viterbi'); pause;
% ylim([0.33 0.62]);

% my_plot(ITERATION_RANGE,STATE_NO_RANGE,error_rate_Viterbi_forward,'Viterbi','Forward'); pause;
% ylim([0.33 0.62]);

% my_plot(ITERATION_RANGE,STATE_NO_RANGE,error_rate_Viterbi_Viterbi,'Viterbi','Viterbi'); pause;
% ylim([0.33 0.62]);

    function h=my_plot(ITERATION_RANGE,STATE_NO_RANGE,error_rate_Iter_D_S,str_model,str_recognizer)
        st_no=STATE_NO_RANGE(1);
        h=plot(ITERATION_RANGE,error_rate_Iter_D_S(ITERATION_RANGE,st_no),'-o', ...
            ITERATION_RANGE,error_rate_Iter_D_S(ITERATION_RANGE,st_no+1),'-*', ...
            ITERATION_RANGE,error_rate_Iter_D_S(ITERATION_RANGE,st_no+2),'-d', ...
            ITERATION_RANGE,error_rate_Iter_D_S(ITERATION_RANGE,st_no+3),'-s' ...
            );
        legend([num2str(st_no) '-state'],[num2str(st_no+1) '-state'],[num2str(st_no+2) '-state'],[num2str(st_no+3) '-state'],[num2str(st_no+4) '-state'],[num2str(st_no+5) '-state']);
        title(['error rate for hmm, train:' str_model  ', decode:' str_recognizer] );
        xlabel('no. of training iterations','fontsize',8);
        ylabel('error rate (%)','fontsize',8);
        set(gca,'XTick',ITERATION_RANGE);
        set(h,'LineWidth',1,'MarkerSize',5);
        % ylim([0.4 0.92])
    end

end

