class RememberYou::RecordsController < ApplicationController
  before_action :authenticate_user!, only: [:new, :show, :edit, :search]
  before_action :set_q, only: [:index, :search]
  before_action :guest_check, only: [:create, :update, :destroy]
  require 'csv'

  def index
    if user_signed_in?
      @teams = Team.where(user_id: current_user.id).includes(:user)
      respond_to do |format|
        format.html
        format.csv do |csv|
          send_teams_csv(@teams)
        end
      end
    else
      @teams = Team.all
    end
  end

  def new
    @user = current_user
    @team = Team.new
    @team.students.build
    @team.teachers.build
    @team.schools.build
  end

  def create
    @user = current_user
    @team = Team.new(team_params.
    tap do |p|
      p[:teachers_attributes].delete_if { |t_a| t_a[:teacher_availability] == "false" }
    end.
    tap do |p|
      p[:students_attributes].delete_if { |s_a| s_a[:student_availability] == "false" }
    end)
    if @team.save
      flash[:success] = "保存されました"
      redirect_to remember_you_records_path
    else
      flash.now[:failer] = "保存できませんでした"
      render new_remember_you_record_path
    end
  end

  def show
    @user = current_user
    @team = Team.find(params[:id])
    @teachers = @team.teachers
    @students = @team.students
    @schools = @team.schools
  end

  def send_teams_csv(teams)
    csv_data = CSV.generate do |csv|
      header = %w(卒業年度 学校名 成人式 教員氏名 立場 備考欄 生徒氏名 氏名カナ 部活動 備考欄)
      csv << header
      teams.each do |team|
        team.schools.each do |school|
          team.teachers.each do |teacher|
            team.students.each do |student|
              values = [
                team.graduation, school.school_name, school.ceremony,
                teacher.teacher_name, teacher.teacher_position, teacher.teacher_others,
                student.student_name, student.student_kana, student.student_club, student.student_others,
              ]
              csv << values
            end
          end
        end
      end
    end
    send_data(csv_data, filename: "teams.csv")
  end

  def edit
    @user = current_user
    @team = Team.find(params[:id])
  end

  def update
    @user = current_user
    @team = Team.find(params[:id])
    if @team.update(team_params)
      flash[:success] = "保存されました"
      redirect_to remember_you_records_path
    else
      flash.now[:failer] = "保存できませんでした"
      render "edit"
    end
  end

  def destroy
    @user = current_user
    @team = Team.find(params[:id])
    @team.destroy
    flash[:delete] = "削除しました"
    redirect_to remember_you_records_path
  end

  def search
    @results = @q.result.where(user_id: current_user.id).includes(:user).distinct
  end

  def guest_check
    if current_user == User.find_by(email: "guests@example.com")
      flash[:notice] = "データの新規作成・編集・削除には会員登録が必要です。"
      redirect_to remember_you_records_path
    end
  end

  private

  def team_params
    params.require(:team).permit(:id, :user_id, :graduation,
    teachers_attributes: [:id, :user_id, :team_id, :teacher_name, :teacher_position, :teacher_others, :teacher_availability],
    students_attributes: [:id, :user_id, :team_id, :student_name, :student_kana, :student_club, :student_others, :student_availability],
    schools_attributes: [:id, :user_id, :team_id, :school_name, :kind, :ceremony])
  end

  def set_q
    @q = Team.ransack(params[:q])
  end
end
