USE [QRBPIBANK]
GO

/****** Object:  StoredProcedure [dbo].[Usp_Insert_Merchant_Txns]    Script Date: 9/26/2025 1:38:53 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[Usp_Insert_Merchant_Txns]
(@inst_id					int,
@rrn						varchar	(35),
@stan						varchar	(20),
@txn_date_time				varchar	(20),
@channel_id					varchar	(30),
@benf_id					varchar	(30),
@benf_name					varchar	(50),
@benf_acct_no				nvarchar(50),
@benf_proxy					varchar	(50),
@benf_tid_pan				nvarchar(50),
@benf_bic					varchar	(11),
@benf_country				varchar	(5),
@benf_city					varchar	(50),
@benf_postal_code			varchar	(16),
@benf_mobile_no				varchar	(15),
@txn_amt					decimal	(18,2),
@txn_curr					varchar	(5),
@bill_amt					decimal	(18,2),
@bill_curr					varchar	(5),
@conv_rate					decimal	(18,2),
@conv_ind					varchar	(5),
@conv_amt					decimal	(18,2),
@rem_name					varchar	(150),
@rem_acct_no				nvarchar(50),
@rem_acct_type				varchar	(2),
@rem_proxy					varchar	(50),
@rem_id_type				varchar	(10),
@rem_id						varchar	(150),
@rem_nationality			varchar	(20),
@rem_city					varchar	(30),
@rem_postal_code			varchar	(16),
@rem_country				varchar	(30),
@rem_dob					varchar	(10),
@rem_country_of_birth		varchar	(2),
@rem_mcc					varchar	(4),
@addtnl_key_1				varchar	(25), 
@addtnl_val_1				varchar	(25),
@addtnl_key_2				varchar	(25),
@addtnl_val_2				varchar	(25),
@addtnl_key_3				varchar	(25),
@addtnl_val_3				varchar	(25),
@payment_mode				varchar	(5),
@interchange				varchar	(5),
@rfrd_doc_infcode			varchar	(5),
@doc_type					varchar	(5),
@linked_refno				varchar	(35),
@doc_date					varchar	(10),
@rmt_lctn_mtd				varchar	(5),
@addtnl_rmtinf				varchar	(1500),
@txn_status					int, --1-Success 2-Failed 3-in Progrerss 4-timeout 5-cancel	
@qr_tag_28					varchar	(500),
@qr_tag_88					varchar	(500),
@txn_type					varchar(10),
@in_out_type				varchar(10),
@bill_no					varchar(25),
@qr_tag_62					varchar(500),
@terminal_labl				varchar(50),
@store_labl					varchar(50),
@rem_bic					varchar(11),
@txn_ref_id                  varchar(35),    -----added on 06012022 added by vaibhav
@txn_instr_id                varchar(35),	   -----added on 06012022 added by vaibhav
@txn_id                  varchar(35),	   -----added on 06012022 added by vaibhav
@benf_online_credit_flag    varchar(1) OUT, --0-Online 1-OCF 2-Handoff
@Biller_Code                nvarchar(50) out,      --Added by vaibhav for p2b transaction 05-07-2022
@Product_Code               nvarchar(50) out,      --Added by vaibhav for p2b transaction 05-07-2022
@Financial_inst_no          nvarchar(50) out,      --Added by vaibhav for p2b transaction 05-07-2022
@Biller_Acc_No              nvarchar(50) out,      --Added by vaibhav for p2b transaction 05-07-2022
@resp_code					varchar(10) OUT,
@resp_msg					varchar(500) OUT,
@biller_class               nvarchar(2) out,
@biller_api_validation      nvarchar(2) out,
@validation_modulo          nvarchar(100) out,
@validation_url             nvarchar(300) out,
@feeamt						varchar(100) out,
@comm_post_type				varchar(5) out,
@biller_pay_validation		char(5) out,
@prdct_id					varchar(15) out,
@notifyFlag					varchar(5) out	,	--added paresh 06032023
@uuid                       varchar(100)
--@txnCurrency				varchar(5) out		--added on 2024-05-22
)
AS
BEGIN
	
	SET @resp_code='EN00';
	SET @resp_msg='SUCCESS';

	BEGIN TRY
	
	DECLARE @product_id	varchar(15),@bancnet_biller_code varchar(10),@bancnet_biller_id	varchar(30),@platfrom_id varchar(10),
			@PlatformIdIncomingQRTxn VARCHAR(50),@PlatformIdIncomingNonQRTxn VARCHAR(50),@collection_report_type varchar(5)--0-Online 1-OCF 2-Handoff 3-Both
			,@response_msg VARCHAR(500),@fee_plan_id bigint, @fee_amt decimal(18, 2) , @v_txn_catg CHAR(1),@v_platform_chnl_id varchar(10),
			@merchant_id varchar(20),@transaction_flag varchar(5),@prod_stat_flag varchar(5),@mer_stat_flag varchar(5),@prod_txn_curr varchar(5)
			,@P2MicroThresholdAmt varchar(255),@ismicromerchant varchar(5),@b_amt decimal(18,2),
			@type_flag varchar(5),@iso_code varchar(20) , @device_serial_no varchar(20) , @qr_ref_label varchar(35) , @device_type varchar(30),
			@iso_qrcode_entry_id bigint , @iso_txn_status varchar(10)
			,@cso_fee decimal(18,2),@ofi_fee decimal(18,2),@rfi_fee decimal(18,2),@en_fee decimal(18,2) ,@mdr_perc decimal(18,2),@merc_share DECIMAL(18,2),@qr_ref_label_prefix varchar(10);--add @merc_share
	--BEGIN TRANSACTION	
		
		EXEC dbo.uspOpenKey
		/*--IF @txn_type in ('QP2M','QP2E')
		--BEGIN
		--     SELECT @product_id = product_id,
		--		 @bancnet_biller_code = bancnet_biller_code,
		--		 @bancnet_biller_id = bancnet_biller_id,
		--		 @benf_online_credit_flag = CASE WHEN ts_post_flag = 1 THEN biller_credit_type ELSE ts_post_flag END,
		--		 @collection_report_type = biller_credit_type,
		--		 @comm_post_type	 = comm_post_type
		--	 FROM dbo.qr_product_mast
		--     WHERE inst_id = @inst_id
		--	 AND stat_flag = 1
		--	 AND (product_id = @benf_id OR bancnet_biller_id = @benf_id)

		--END*/ --comented as clubbed below

		--SET @notifyFlag = (select tag28_notify_flag from qr_product_mast where product_id = @benf_id)
		  
		SET @ismicromerchant = (select micro_merchant from qr_product_mast (nolock) where product_id = @benf_id )

		IF @interchange = 'B' 
		  BEGIN
		    SELECT @PlatformIdIncomingQRTxn = ParamValue 
		    FROM dbo.qr_inst_param 
		    WHERE ParamKey = 'PlatformIdIncomingQRTxn'

		    SELECT @PlatformIdIncomingNonQRTxn = ParamValue 
		    FROM dbo.qr_inst_param 
		    WHERE ParamKey = 'PlatformIdIncomingNonQRTxn'
		 

		    SET @platfrom_id = CASE WHEN @in_out_type = 'IN' AND @txn_type = 'IBPS' THEN @PlatformIdIncomingNonQRTxn
								 WHEN @in_out_type = 'IN' AND @txn_type IN ('QBPS','QP2M','QP2E') THEN @PlatformIdIncomingQRTxn
								 ELSE NULL END

								 

			/*start added paresh 19-10-2022*/
		    IF (isnull(@channel_id,'') = '')
			  BEGIN
				SET @channel_id = (select top 1 cm.channel_id 
									from qr_channel_mast cm 
									inner join qr_platfrom_chnnl_mast pm on pm.platfrom_chnnl_id=cm.platfrom_id
									where pm.platfrom_id=@platfrom_id)
			END
         END

		 IF @interchange = 'O'
		 BEGIN
			
			SELECT @platfrom_id = plt.platfrom_id 
			from dbo.qr_channel_mast chnl , qr_platfrom_chnnl_mast plt  
			where plt.platfrom_chnnl_id = chnl.platfrom_id
			and chnl.channel_id = @channel_id
		 END


		 SELECT @P2MicroThresholdAmt = ParamValue 
		  FROM dbo.qr_inst_param 
		  WHERE ParamKey = 'P2MicroThresholdAmt'


		 /*end added paresh 19-10-2022*/						 
		 ---SN for p2b transaction---------added by vaibhav 06-07-2022
		 if @txn_type in('QBPS','IBPS','QP2M','QP2E')
		 begin
				--set @resp_code=(case when not exists(select 1 from qr_product_mast where bancnet_biller_id = @benf_id and inst_id=@inst_id)	then 'EN162'  
				--                     when not exists( select 1 from qr_merchant_mast where inst_id=@inst_id and merchant_id=(select merchant_id from qr_product_mast where inst_id=@inst_id and bancnet_biller_id = @benf_id )) then 'EN161' end)

				
		 begin
		  select @Biller_Acc_No=pm.acct_no,@product_id = product_id,@Product_Code=pm.product_code,@Financial_inst_no=pm.financial_inst_no,@Biller_Code=mm.merchant_code
			--@benf_online_credit_flag = CASE WHEN ts_post_flag = 1 THEN biller_credit_type ELSE ts_post_flag END,
			,@benf_online_credit_flag = ts_post_flag
			,@collection_report_type = biller_credit_type,@biller_class=biller_type,@biller_api_validation=biller_info_validate
			,@validation_modulo=validation_modulo,@validation_url=validation_url,@transaction_flag=pm.qr_transaction_flag
			,@merchant_id=pm.merchant_id,@prod_stat_flag=pm.stat_flag,@mer_stat_flag=mm.stat_flag,@prod_txn_curr=pm.curr
			,@comm_post_type	 = pm.comm_post_type
			,@biller_pay_validation = pm.payment_validation		--added 02012023
			,@notifyFlag = tag28_notify_flag, @ismicromerchant = micro_merchant,@prdct_id = @product_id
			,@type_flag = pm.type_flag , @iso_code = case isnull(mm.iso_code ,'NA') WHEN 'NA' then 'BPI'   else mm.iso_code end 
			from qr_product_mast (nolock) pm
			inner join qr_merchant_mast (nolock) mm on mm.merchant_id=pm.merchant_id
			where (product_id = @benf_id OR bancnet_biller_id = @benf_id) and pm.inst_id=@inst_id

					--set @prdct_id = @product_id		--added 02012023
					--set @txnCurrency =(select iso4217_currency_codealpha from qr_currency_mast where iso4217_currency_codenum=@prod_txn_curr)	--added on 2024-05-22
		 end
		 if @@rowcount=0
		 begin
		   set @resp_code='EN494'
		   SET @resp_msg='FAILURE';
		   goto l_err
		 end

		 /* SN ISO POS - 22-DEC-2014 Changes added to identify the Transaction done using QR Generated on ISO POS terminals*/
		 if @txn_type in('QP2M','QP2E') and @iso_code <> 'BPI'
		 begin
			-- Check qr tag 62-05 value received in transaction
			set @qr_ref_label =	case when @addtnl_key_1 = '05' then @addtnl_val_1 when @addtnl_key_2 = '05' then @addtnl_val_2 end
			set @qr_ref_label_prefix = (SELECT param_value FROM dbo.qr_param_config WHERE param_key = 'POS_QR_REF_NUMBER_PREFIX')
			
			
			--10-Apr-2025 - Condition added in order to check the reference number for QR generated through POS device 
			
			if left(@qr_ref_label,3)=@qr_ref_label_prefix --or exists(select 1 from qr_iso_qrcode_entries where qr_reference_label = @qr_ref_label))
			begin
					select	@device_serial_no = tm.device_serial_no , 
							@device_type = tm.device_type , 
							@iso_qrcode_entry_id = isoqr.qrcode_entry_id,
							@iso_txn_status = isoqr.txn_status
					from qr_product_mast (nolock) prod  
					inner join qr_terminal_mapping (nolock) tm  on tm.product_id = prod.product_id and tm.product_id = @benf_id and tm.status = '1'
					inner join qr_iso_qrcode_entries(nolock) isoqr on isoqr.product_id = tm.product_id and tm.device_serial_no = isoqr.device_serial_no and isoqr.qr_reference_label = @qr_ref_label
		
					if @device_serial_no is null
					begin 		
						set @resp_code='EN408'
						SET @resp_msg='FAILURE'
						goto l_err
					end
					--If transaction is already processed then do not process transaction again decline with duplicate transaction error code
					if @iso_txn_status = 'SUCCESS' or @iso_txn_status = 'FAILED'
					begin	
						SET @resp_code='EN438'
						SET @resp_msg='FAILURE';
						goto l_err
					end
			end
			else
			begin
				 set @resp_code='EN00'
				set @resp_msg='SUCCESS'	
			end
		 end

		/*EN ISO POS - 22-DEC-2014*/
				
		if (@txn_type IN('QBPS','IBPS') and @type_flag = 'M')
			begin
				set @resp_code='EN320'
				SET @resp_msg='FAILURE';
				goto l_err
		END
		else if (@txn_type IN('QP2M','QP2E') and @type_flag = 'B')
		begin
			set @resp_code='EN320'
			SET @resp_msg='FAILURE';
			goto l_err
		END
		else if (@txn_type='QP2E' and @ismicromerchant != 'Y')
			begin
				set @resp_code='EN320'
				SET @resp_msg='FAILURE';
				goto l_err
			END
		else if (@txn_type='QP2M' and @ismicromerchant = 'Y')
			begin
				set @resp_code='EN320'
				SET @resp_msg='FAILURE';
				goto l_err
			END
		else if (@prod_stat_flag<>1)
			begin
				set @resp_code='EN408'
				SET @resp_msg='FAILURE';
				goto l_err
			end
		else if (@mer_stat_flag<>1)
			begin
				set @resp_code='EN408'
				SET @resp_msg='FAILURE';
				goto l_err
			end
		else if (@txn_type IN ('QBPS','QP2M','QP2E') and @transaction_flag not in (1,3))
			begin
				set @resp_code='EN320'
				SET @resp_msg='FAILURE';
				goto l_err
			END
		else if (@txn_type='IBPS' and @transaction_flag not in (2,3))
			begin
				set @resp_code='EN320'
				SET @resp_msg='FAILURE';
				goto l_err
			END
		else if (@prod_txn_curr <> @txn_curr)
			begin
				set @resp_code='EN554'
				SET @resp_msg='FAILURE';
				goto l_err
			END
				
		end	
	   ------- SN End for p2b transaction---------------------------------
		/*--IF EXISTS (SELECT 1 FROM  dbo.qr_merchant_txns_dtls
		--				   WHERE inst_id = @inst_id 
		--					 AND txn_date_time = @txn_date_time							 
		--					 AND rrn = @rrn
		--					 AND channel_id = @channel_id
		--					 AND txn_amt = @txn_amt
		--					 AND stan = @stan
		--					 AND qr_resp_code = 'EN00') 
		--BEGIN
		--	SET @resp_code='EN40'
		--	SET @resp_msg='FAILURE';
		--	GOTO l_err
		--END
		*/--comented as it is not required discussed with nishikant
		
		

		BEGIN
 
			if @txn_type in('QBPS','QP2M','QP2E')  
			begin	
				set @v_txn_catg='Q'  --- QR Transaction 
			end
			else if @txn_type in ('IBPS')
			begin	
				set @v_txn_catg= 'N'  --- NON QR Transaction
			end

			select @v_platform_chnl_id = platfrom_chnnl_id from qr_platfrom_chnnl_mast where platfrom_id=@platfrom_id and stat_flag = '1'
			
			IF @ismicromerchant = 'Y' and @txn_amt < @P2MicroThresholdAmt
				BEGIN
					set @fee_amt = 0
				END
			ELSE
				BEGIN
					IF @iso_code <> 'BPI'
						BEGIN
							EXEC [dbo].[Usp_Mdr_Calc_ISO] @inst_id ,@iso_code, @product_id, @txn_amt,@v_platform_chnl_id,@v_txn_catg , @interchange ,@fee_amt OUTPUT,@fee_plan_id OUTPUT,@resp_msg OUTPUT,@cso_fee OUTPUT,@ofi_fee OUTPUT,@rfi_fee OUTPUT,@en_fee OUTPUT , @mdr_perc OUTPUT
						END
					ELSE
						BEGIN

							EXEC [dbo].[Usp_Mdr_Calc] @inst_id, @product_id, @txn_amt,@v_platform_chnl_id,@v_txn_catg,@fee_amt OUTPUT, @fee_plan_id  OUTPUT,@resp_msg OUTPUT,@merc_share OUTPUT

						END

					if @resp_msg!='OK'
						begin
							set @resp_code='EN01'
							GOTO l_err
						end
					else
						begin
							   SET @resp_code='EN00'
							   set @resp_msg='SUCCESS'
						end
				END
		END
		
		--SN: Added On 14032023 For Limits Check
		IF @txn_type IN ('QP2M','QP2E') 
			BEGIN
				--SET @b_amt=[dbo].[fnConvertAmt](@txn_amt,@txn_curr)
				EXEC [dbo].[usp_limits_checks] 'RI',@inst_id,NULL,NULL,@product_id,NULL,@txn_amt,@resp_code OUT,@resp_msg OUT--,@l_errmsg OUT

				/*IF @l_errmsg!='OK'
				BEGIN
					--ROLLBACK TRANSACTION
					--RETURN
						SET @resp_msg = 'EN01'
				END*/
			END
			--EN: Added On 14032023 For Limits Check

		l_err:
		BEGIN

		--CREATE tABLE dd(fee varchar(10),mer varchar(10))


			set @feeamt=isnull(@fee_amt,0)
			--PRINT @merc_share1; 
			PRINT @fee_amt;

			INSERT INTO dbo.qr_merchant_txns_dtls
						(inst_id,txn_date_time,rrn,stan,instr_id,channel_id,benf_id,bancnet_benf_id,benf_name,
						 benf_acct_no,benf_acct_no_encr,benf_acct_no_mask,
						 benf_proxy,benf_tid,
						 benf_tid_pan,benf_tid_pan_encr,benf_tid_pan_mask,
						 benf_bic,benf_country,benf_city,benf_postal_code,benf_mobile_no,benf_online_credit_flag,txn_amt,txn_curr,bill_amt,bill_curr,conv_rate,conv_ind,conv_amt,rem_name,
						 rem_acct_no,rem_acct_no_encr,rem_acct_no_mask,
						 rem_acct_type,rem_proxy,rem_id_type,rem_id,rem_nationality,rem_city,rem_postal_code,rem_country,rem_dob,rem_country_of_birth,rem_mcc,
						 addtnl_key_1,addtnl_val_1,addtnl_key_2,addtnl_val_2,addtnl_key_3,addtnl_val_3,payment_mode,interchange,rfrd_doc_infcode,doc_type,linked_refno,doc_date,rmt_lctn_mtd,
						 addtnl_rmtinf,txn_status,txn_type,qr_resp_code,qr_resp_msg,qr_tag_28,qr_tag_88,refund_flag,org_rrn,org_stan,org_instr_id,ocf_gen_flag,handoff_gen_flag,in_out_type,
						 bill_no,qr_tag_62,terminal_labl,store_labl,platform_id,collection_report_type,rem_bic,txn_instr_id,txn_ref_id,txn_id,biller_class,mdr_fee,rcvd_benf_acct_no_encr,rcvd_benf_acct_no_mask,proc_dt,comm_post_type,channel_req_ref_no,iso_code , device_serial_no , device_type,uuid_acct_info,
						 mdr_bank_share , mdr_en_share , mdr_cso_share , mdr_ofi_share , mdr_perc,merc_share
						 )--add merc_share
				 VALUES 
						(@inst_id,@txn_date_time,@rrn,@stan,NULL,@channel_id,@benf_id,@bancnet_biller_id,@benf_name,
						 dbo.gethashvalue(@Biller_Acc_No),EncryptByKey(Key_GUID('Symkey'),cast(@Biller_Acc_No as nvarchar(200))),dbo.fnGetMaskedPan(@Biller_Acc_No),
						 @benf_proxy,NULL,--@benf_tid
						 dbo.gethashvalue(@benf_tid_pan),EncryptByKey(Key_GUID('Symkey'),cast(@benf_tid_pan as nvarchar(200))),dbo.fnGetMaskedPan(@benf_tid_pan),						 
						 @benf_bic,@benf_country,@benf_city,@benf_postal_code,@benf_mobile_no,@benf_online_credit_flag,@txn_amt,@txn_curr,@bill_amt,@bill_curr,@conv_rate,@conv_ind,@conv_amt,@rem_name,
						 dbo.gethashvalue(@rem_acct_no),EncryptByKey(Key_GUID('Symkey'),cast(@rem_acct_no as nvarchar(200))),dbo.fnGetMaskedPan(@rem_acct_no),
						 @rem_acct_type,@rem_proxy,@rem_id_type,@rem_id,@rem_nationality,@rem_city,@rem_postal_code,@rem_country,@rem_dob,@rem_country_of_birth,@rem_mcc,
						 @addtnl_key_1,@addtnl_val_1,@addtnl_key_2,@addtnl_val_2,@addtnl_key_3,@addtnl_val_3,@payment_mode,@interchange,@rfrd_doc_infcode,@doc_type,@linked_refno,@doc_date,@rmt_lctn_mtd,
						 @addtnl_rmtinf,@txn_status,@txn_type,@resp_code,@resp_msg,@qr_tag_28,@qr_tag_88,NULL,NULL,NULL,NULL,'N','N',@in_out_type,
						 @bill_no,@qr_tag_62,@terminal_labl,@store_labl,@platfrom_id,@collection_report_type,@rem_bic,@txn_instr_id,@txn_ref_id,@txn_id,@biller_class,@feeamt,EncryptByKey(Key_GUID('Symkey'),cast(@benf_acct_no as nvarchar(200))),dbo.fnGetMaskedPan(@benf_acct_no),(select nxt_proc_dt from dbo.qr_procdt_dtl where proc_type=case @comm_post_type when 0 then 'DCOM' when 1 then 'MCOM' end), @comm_post_type,@txn_ref_id , @iso_code , @device_serial_no , @device_type,@uuid,
						 @rfi_fee , @en_fee ,@cso_fee , @ofi_fee , @mdr_perc,@merc_share
						 )
		
		
			/** 
				If transaction is identified as iso  QR transaction and transaction is not duplicate then update the 
				QR code entry with the transction status
			**/
			IF @iso_qrcode_entry_id is not null and @resp_code <> 'EN438'
				BEGIN
					
					set @iso_txn_status	= case @resp_code when 'EN00' then 'PENDING' else 'FAILED' end
					update qr_iso_qrcode_entries set instr_id = @txn_instr_id ,txn_status = @iso_txn_status, rem_bic=@rem_bic,amount_received=@txn_amt where qrcode_entry_id = @iso_qrcode_entry_id

				END
		
		END	

		--BEGIN
		--	IF @resp_code!='EN00'
		--		SET @resp_msg= 'FAILED'
		--	ELSE
		--	   SET @resp_msg= 'SUCCESS'
		--	   SET @resp_code= 'EN00'
		--END	
		
	END TRY

	BEGIN CATCH
		SET @resp_msg = 'EN01'
		SET @resp_code = 'EN01'
		
		--ROLLBACK TRANSACTION
		INSERT INTO qr_err_log(ApplicationType,Source,UrlValue,Message)
		                VALUES('[Usp_Insert_MerchantTxns]',ERROR_PROCEDURE(), ERROR_LINE(),'Instr_id '+@txn_instr_id+'-'+ERROR_MESSAGE())
	END CATCH						   
END





GO

