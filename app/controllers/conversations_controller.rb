# frozen_string_literal: true
class ConversationsController < ApplicationController
  require 'will_paginate/array'

  before_action :authenticate_user!

  def index
    @conversations = current_user.mailbox
                                 .conversations(mailbox_type: 'not_trash')
                                 .includes(:receipts)
                                 .sort_by { |c| c.last_message.created_at }
                                 .reverse

    @conversations = @conversations.paginate(page: params[:page], total_entries: @conversations.to_a.size)
  end

  def new
    @message = Mailboxer::Message.new
    @recipient = User.find(params[:user_id])
    @message.recipients = @recipient.id if params[:user_id]
  end

  def create
    @message = Mailboxer::Message.new message_params

    recipient = User.find(recipient_id)
    receipt = current_user.send_message([recipient], @message.body, @message.subject)
    @conversation = receipt.notification.conversation

    return render_new_with(recipient, receipt) unless receipt.valid?

    redirect_to mailboxer_conversation_path(@conversation),
                notice: I18n.t('mailboxer.notifications.sent')
  end

  def update
    @message = Mailboxer::Message.new message_params

    @conversation = conversations.find(@message.conversation_id)

    return render_show_with(interlocutor(@conversation)) unless @message.valid?

    current_user.reply_to_conversation(@conversation, @message.body)

    redirect_to mailboxer_conversation_path(@conversation),
                notice: I18n.t('mailboxer.notifications.sent')
  end

  # GET /messages/:ID
  # GET /message/show/:ID/subject/SUBJECT
  def show
    @conversation = conversations.find(params[:id])

    @message = Mailboxer::Message.new conversation_id: @conversation.id
    current_user.mark_as_read(@conversation)
  end

  def trash
    conversation = conversations.find(params[:id] || params[:conversations])
    current_user.trash(conversation)
    flash[:notice] = I18n.t 'mailboxer.notifications.trash'
    redirect_to mailboxer_conversations_path
  end

  private

  # Never trust parameters from the scary internet, only allow the white list through.
  def message_params
    params.require(:mailboxer_message)
          .permit(:conversation_id, :body, :subject, :recipients)
          .merge(sender: current_user)
  end

  def recipient_id
    params[:mailboxer_message][:recipients].to_i
  end

  def render_show_with(recipient)
    @message.recipients = recipient.id
    render :show
  end

  def render_new_with(recipient, receipt)
    missing_subject = receipt.errors['notification.conversation.subject'].first
    missing_body = receipt.errors['notification.body'].first
    @message.errors.add(:subject, missing_subject) if missing_subject
    @message.errors.add(:body, missing_body) if missing_body
    @recipient = recipient
    @message.recipients = @recipient.id
    render :new
  end

  def conversations
    current_user.mailbox.conversations
  end

  def interlocutor(conversation)
    conversation.recipients.find { |u| u != current_user }
  end

  helper_method :interlocutor
end
