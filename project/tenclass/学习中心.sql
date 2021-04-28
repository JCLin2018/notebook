
3462  -- 用户:zZ


-- ====================== 课程详情 ======================

-- 课程表
select * from study_course where id = 285 -- 训练营课程
select * from study_course where id = 313 -- 训练营课程
select * from study_course where id = 286 -- 普通课程


-- ====普通课程====
select * from study_course_ordinary where course_id = 286 -- id:85 普通课程天数
select * from study_course_ordinary_rule where course_id = 286  -- 普通课程规则


-- ====================== 训练营课程 ======================

-- ====训练营课程====
select * from study_course_training where course_id = 313 -- id:225 训练营课程天数
select * from study_course_training_camp where training_id = 225 -- id:252,286 训练营-营期
-- 营期状态 com.tenclass.center.study.api.enums.TrainingCampStatus

select * from study_course_training_temp_user where training_id = 225 -- 训练营-临时营期-用户
select * from study_course_training_camp_user where training_id = 225 -- 训练营-营期-用户


-- 课程目录表
select * from study_course_directory where object_id = 252 and course_type = 'training'  -- study_course_training_camp:id || study_course_ordinary:id
select * from study_course_directory where object_id = 286 and course_type = 'training'  -- study_course_training_camp:id || study_course_ordinary:id
-- 课程目录对应 课程内容表
select * from study_course_directory_content_relation where study_course_directory_id = 1925
select * from study_course_directory_content_relation where study_course_directory_id in (
select id from study_course_directory where object_id = 252 and course_type = 'training'
)


-- 课程内容表
select * from study_course_content where course_id = 285 
select * from study_course_content where course_id = 1091 

-- 课程目录与课程内容关联查询
select * from study_course_content where id in (
	select study_course_content_id from study_course_directory_content_relation where study_course_directory_id in (
	select id from study_course_directory where object_id = 252 and course_type = 'training'
	)
) 
and content_type = 'live_practice'



-- ====================================== 课程内容有四类 ======================================
1. 音频
2. 录播
3. 直播
4. 视频实操
5. 女娲直播实操


-- 1.音频
select * from content_audio where content_id = 1212
-- 2.录播
select * from content_video where content_id = 1099
-- 3.直播
select * from content_live where content_id in (1133,1135,1157,1159)
		-- 主播表
select * from content_live_anchor where id in (117,118)  -- content_live:anchor_id
		-- 直播助理
select * from content_live_assistant where live_number = '836614753123176448' -- content_live:live_number
-- 4.视频实操
select * from video_course where content_id = 1137 -- 125
		-- 视频素材表
select * from video_material where course_id = 125  -- video_course:id
		-- 列表记录表（无关业务）
select * from video_online_list where course_id = 125  -- video_course:id
		-- 学员请求连接表
select * from video_customer_computer_help where user_id = 3642 and course_id = 125 -- video_course:id
		-- 用户作业操作表
select * from video_homework_op_history where video_id = 1125 -- !!!
		-- 关键帧
select * from video_frame where course_id = 125  -- video_course:id
		-- 录播实操作业
select * from video_homework where course_id = 125
				-- 学员作业记录
		select * from video_homework_record where homework_id = 1 -- video_homework:id
				-- 视频作业教程表
		select * from video_homework_skin where homework_id = 1 -- video_homework:id

		-- 学员视频进度表
select * from video_course_play_progress where user_id = 3462 and course_id = 125

		-- 用户连接表
select * from video_customer_computer_connection where course_id = 125
				-- 用户连接记录表
		select * from video_customer_computer_connection_record where course_id = 125 -- video_customer_computer_connection:id
		
-- 5.直播实操课
select * from content_live_practice where content_id = 1091 -- 282
		-- 直播素材
select * from content_practice_material where content_id = 282
		-- 直播实操作业
select * from content_live_practice_homework where content_id = 282 
				-- 作业指引
	select * from content_live_practice_homework_guide where homework_id = 103 -- content_live_practice_homework:id
				-- 直播实操作业记录
	select * from content_live_practice_homework_access where homework_id = 103 -- content_live_practice_homework:id
				-- 老师作业操作记录表
	select * from content_live_practice_homework_operate where homework_id = 103 -- content_live_practice_homework:id


		
		

select * from study_course_pro_share where course_id = 285 -- 课程-分享信息
select * from study_course_pro_pay_boot where course_id = 285 -- 课程-支付路径


select * from study_experience where course_id = 285 -- 学习心得
select * from study_experience_like -- 学习心得点赞
select * from study_experience_comment -- 学习心得评论





-- 课程皮肤
select * from skin_relation where course_id = 285 -- 课程皮肤关联表
select * from skin where id = 141  -- 皮肤

-- 课程提醒
select * from study_course_content_remind where content_id = 988 -- 课程提醒配置表
select * from study_course_content_remind_template  -- 普通课程规则表

-- 
select * from course_content_access -- 录播课访问记录表



select * from study_course_content where object_id = 230  -- 课程内容

select * from skin_retain_page -- 学习笔记


-- ================ 课程用户购买权限 ================

-- 单个课程的权限
select * from study_course_access where user_id = 3462 and course_id = 313

-- 组合课程的权限
select * from study_assembly_course_item where course_id = 313 and is_deleted = 0 
select * from study_assembly_course_access where user_id = 3462 and assembly_id in (18,13,22)






-- 直播
select * from content_live    -- 内容直播课
select * from content_live_assistant -- 



-- 伪直播模板是通过正直播可回放记录进行拉取的
select * from content_live_playback -- 直播回放表

select * from course_content_sale_rel






-- 题库管理
select * from question_bank where shop_id = 1 -- 题库表
select * from question where question_bank_id = 197  -- 习题表



select * from skin_relation

-- 渠道管理

select * from source where id = 1042
select * from course_content_source_rel where 











