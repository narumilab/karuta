main.m

  -generate_LR_HMM_skips_structure
  
  -global_mean_var_for_hmm_skips_1gau
  
  -EM_hmm_skips_1gau
  
    -Forward_backward_hmm_skips_1gau_log_math  
  
      -forward_hmm_skips_1gau_log_math
       
        -logDiagGaussian
        
        -logSum
        
          -overall_max
          
          -overall_sum
      
      -logSum
      
  
  -recognition_Viterbi_hmm_skips_1gau_no_terminal
  
    -viterbi_hmm_LR_skips_1gau_no_terminal
    
      -logDiagGaussian
  
  -ｍain_dr_wav2mfcc_e_d_a
  
    -dr_wav2mfcc_e_d_a
    
      -fwav2mfcc_e_d_a
      
        -wav2mfcc_e_d_a
        
          -wav2mfcc
          
          -wav2logpow
          
          -Slope


final_fig.m

  -state_check.m
