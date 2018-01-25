class App < Sinatra::Base

	enable :sessions

	get '/' do
		slim(:hem)
	end

	get '/start' do
		if session[:user] == nil
			redirect('./')
		end
		db = SQLite3::Database.new("allt.sqlite")
		userid = db.execute("SELECT id FROM users WHERE username = '#{session[:user]}'").join
		result = db.execute("SELECT groupid FROM user_group WHERE userid = #{userid}")
		invites = db.execute("SELECT * FROM invites WHERE invited_user_id = '#{userid}'")
		invites.each_with_index do |x,y|
			invites[y][3] = db.execute("SELECT username FROM users WHERE id = '#{x[3]}'").join
			invites[y] << x[2]
			group_name = db.execute("SELECT name FROM groups WHERE id = '#{x[2]}'").join
			invites[y][2] = group_name
		end
		group_names = []
		result.each_with_index do |x,y|
			result[y] = x.join
			group_names << db.execute("SELECT name FROM groups WHERE id = '#{x.join}'").join
		end
		slim(:start, locals:{result:result, group_names:group_names, invites:invites, userid:userid})
	end
	
	get '/start/groups/create' do
		if session[:user] == nil
			redirect('/')
		end
		slim(:group_create)
	end

	get '/start/groups/:id' do
		if session[:user] == nil
			redirect('./')
		end
		group_id = params["id"].to_i
		db = SQLite3::Database.new("allt.sqlite")
		user_list = db.execute("SELECT userid FROM user_group WHERE groupid ='#{group_id}'")
		group_name = db.execute("SELECT name FROM groups WHERE id ='#{group_id}'").join
		leader_id = db.execute("SELECT group_leader_id FROM groups WHERE id ='#{group_id}'").join
		user_id = db.execute("SELECT id FROM users WHERE username ='#{session[:user]}'").join
		username_list = {}
		user_list.each do |x|
			username = db.execute("SELECT username FROM users WHERE id ='#{x.join}'").join
			username_list[x] = username
		end
		if leader_id == user_id
			slim(:group_if_leader, locals:{group_name:group_name, leader_id:leader_id, user_id:user_id, user_list:user_list, username_list:username_list, group_id:group_id.to_s})
		else
			slim(:group, locals:{group_name:group_name, leader_id:leader_id, user_id:user_id, user_list:user_list, username_list:username_list, group_id:group_id.to_s})
		end
	end

	get '/start/groups/promote/:user_id/:group_id' do
		user_id = params["user_id"]
		group_id = params["group_id"]
		db = SQLite3::Database.new("allt.sqlite")
		db.execute("UPDATE groups SET group_leader_id = '#{user_id}' WHERE id = '#{group_id}'")
		redirect('/start')
	end
	
	get '/start/groups/kick/:user_id/:group_id' do
		user_id = params["user_id"]
		group_id = params["group_id"]
		db = SQLite3::Database.new("allt.sqlite")
		db.execute("DELETE FROM user_group WHERE userid = '#{user_id}' AND groupid = '#{group_id}'")
		redirect('/start')
	end

	get '/start/groups/leave/:user_id/:group_id' do
		user_id = params["user_id"]
		group_id = params["group_id"]
		db = SQLite3::Database.new("allt.sqlite")
		db.execute("DELETE FROM user_group WHERE userid = '#{user_id}' AND groupid = '#{group_id}'")
		redirect('/start')
	end

	get '/start/groups/delete/:group_id' do
		group_id = params["group_id"]
		db = SQLite3::Database.new("allt.sqlite")
		leader_id = db.execute("SELECT group_leader_id FROM groups WHERE id = '#{group_id}'").join
		user_id = db.execute("SELECT id FROM users WHERE username = '#{session[:user]}'").join
		if leader_id != user_id
			redirect("/logout")
		end
		db.execute("DELETE FROM groups WHERE id = '#{group_id}'")
		user_ids = db.execute("SELECT userid FROM user_group WHERE groupid = '#{group_id}'")
		p user_ids
		redirect('/start')
	end
	
	get '/register' do
		slim(:register)
	end

	get '/logout' do
		session[:user] = nil
		redirect('./')
	end

	get '/fail' do
		if session[:fail_message] == nil
			redirect('/')
		end
		slim(:fail, locals:{error_message:session[:fail_message], redirect_to:session[:redirect_to]})
	end

	post "/start/groups/name_change/:group_id" do
		group_id = params["group_id"]
		name = params["name"]
		db = SQLite3::Database.new("allt.sqlite")
		db.execute("UPDATE groups SET name = '#{name}' WHERE id = '#{group_id}'")
		redirect("/start/groups/#{group_id}")
	end

	post '/start/groups/accept/:invite_id' do
		db = SQLite3::Database.new("allt.sqlite")
		invite_id = params["invite_id"]
		db.execute("UPDATE invites SET hidden = '1' WHERE id = '#{invite_id}'")
		inviteinfo = db.execute("SELECT * FROM invites WHERE id = '#{invite_id}'")[0]
		db.execute("INSERT INTO user_group (userid,groupid) VALUES ('#{inviteinfo[1]}','#{inviteinfo[2]}')")
		redirect('/start')
	end
	
	post '/start/groups/decline/:invite_id' do
		db = SQLite3::Database.new("allt.sqlite")
		invite_id = params["invite_id"]
		db.execute("UPDATE invites SET hidden = '1' WHERE id = '#{invite_id}'")
		redirect('/start')
	end

	post '/start/groups/invite/:group_id/:user_id' do
		group_id = params["group_id"]
		inviter_id = params["user_id"]
		username = params["username"]
		db = SQLite3::Database.new("allt.sqlite")
		begin
			user_id = db.execute("SELECT id FROM users WHERE username = '#{username}'").join
		rescue
			session[:fail_message] = "User doesn't exist"
			session[:redirect_to] = "./start/groups/#{group_id}"
			redirect('./fail')
		end
		if user_id == nil
			session[:fail_message] = "User doesn't exist"
			session[:redirect_to] = "./start/groups/#{group_id}"
			redirect('./fail')
		elsif user_id == ""
			session[:fail_message] = "User doesn't exist"
			session[:redirect_to] = "./start/groups/#{group_id}"
			redirect('./fail')
		end
		user_list = db.execute("SELECT userid FROM user_group WHERE groupid = '#{group_id}'")
		user_list.each do |x|
			if user_id == x.join
				session[:fail_message] = "User already in group"
				session[:redirect_to] = "./start/groups/#{group_id}"
				redirect('./fail')
			end
		end
		group_name = db.execute("SELECT name FROM groups WHERE id = '#{group_id}'")
		inviter_name = db.execute("SELECT username FROM users WHERE id ='#{group_id}'")
		hidden = 0
		begin
			db.execute("INSERT INTO invites (invited_user_id,group_id,inviter_user_id,hidden) VALUES ('#{user_id}','#{group_id}','#{inviter_id}','#{hidden}')")
		rescue
			session[:fail_message] = "Something went wrong"
			session[:redirect_to] = "./start/groups/#{group_id}"
			redirect('./fail')
		end
		redirect('/start')
	end

	post '/start/groups/create' do
		db = SQLite3::Database.new("allt.sqlite")
		userid = db.execute("SELECT id FROM users WHERE username = '#{session[:user]}'").join
		group_name = params["group_name"]
		db.execute("INSERT INTO groups (name,group_leader_id) VALUES ('#{group_name}','#{userid.to_s}')")
		groupid = db.execute("SELECT id FROM groups WHERE name = '#{group_name}'").join
		db.execute("INSERT INTO user_group (userid,groupid) VALUES (?,?)", [userid.to_s,groupid.to_s])
		redirect('/start')
	end

	post '/login' do
		username = params["username"]
		password2 = params["password2"]
		password = params["password"]
		if password2 != password
			session[:fail_message] = "Passwords does not match"
			session[:redirect_to] = "./"
			redirect('./fail')
		end
		db = SQLite3::Database.new("allt.sqlite")
		begin
			password_digest = db.execute("SELECT password FROM users WHERE username ='#{username}'").join
			password_digest = BCrypt::Password.new(password_digest)
		rescue
			session[:fail_message] = "Bad login"
			session[:redirect_to] = "./"
			redirect('./fail')
		end
		if password_digest == password
			session[:user] = username
			redirect('./start')
		else
			session[:fail_message] = "Bad login"
			session[:redirect_to] = "./"
			redirect('./fail')
		end
	end

	post '/register' do
		username = params["username"]
		password2 = params["password2"]
		password = params["password"]
		if password2 != password
			session[:fail_message] = "Passwords does not match"
			session[:redirect_to] = "./register"
			redirect('./fail')
		end
		password_digest = BCrypt::Password.create(password)
		db = SQLite3::Database.new("allt.sqlite")
		begin
			db.execute("INSERT INTO users (username, password) VALUES (?,?)",[username,password_digest])
		rescue
			session[:fail_message] = "Username already in use"
			session[:redirect_to] = "./register"
			redirect('./fail')
		end
		redirect('./')
	end
end