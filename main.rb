require 'rubygems'
require 'sinatra'
require 'pry'

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'my_lil_string'

BLACKJACK_AMOUNT = 21
DEALER_MIN_HIT = 17
INITIAL_POT_AMOUNT = 500

helpers do 

  def calculate_total(cards) # cards appear as nested array
    arr = cards.map{|element| element[1]}

    total = 0
    arr.each do |a|
      if a == "A"
        total += 11
      else
        total += a.to_i == 0 ? 10 : a.to_i
      end
    end

    # correct for Aces
    arr.select {|element| element == "A"}.count.times do
      break if total <= BLACKJACK_AMOUNT
      total -= 10
    end

    total
  end

  def card_image(card) 
    suit = case card[0]
      when 'H' then 'hearts'
      when 'D' then 'diamonds'
      when 'C' then 'clubs'
      when 'S' then 'spades'
    end

    value = card[1]
    if ['J', 'Q', 'K', 'A'].include?(value)
      value = case card[1]
        when 'J' then 'jack'
        when 'Q' then 'queen'
        when 'K' then 'king'
        when 'A' then 'ace'
      end
    end

    "<img src='/images/cards/#{suit}_#{value}.jpg' class='card_image'>"
  end

  def winner!(msg)
    @show_hit_or_stay_buttons = false
    @show_play_or_quit_buttons = true
    session[:player_money] = session[:player_money] + session[:player_bet]
    @winner = "<strong>#{session[:player_name]} wins!</strong> #{msg}. #{session[:player_name]} now has <strong>\$#{session[:player_money]}</strong>."
  end

  def loser!(msg)
    if (session[:player_money]) == 0
      redirect '/game_over'
    end
    @show_hit_or_stay_buttons = false
    @show_play_or_quit_buttons = true    
    session[:player_money] = session[:player_money] - session[:player_bet]
    @loser = "<strong>#{session[:player_name]} loses!</strong> #{msg}. #{session[:player_name]} now has <strong>\$#{session[:player_money]}</strong>."
  end

  def tie!(msg)
    @show_hit_or_stay_buttons = false 
    @show_play_or_quit_buttons = true
    @winner = "<strong>It's a tie!</strong> #{msg}."
  end

  # find if bet is a positive integer that is Less Than/Equal to total money available
  def incorrect_bet?(bet)
    bet.to_i == nil ||
    bet.to_i <= 0 ||
    bet.to_i > session[:player_money]
  end

  # find if player is out of money
  def broke?(money)
    money <= 0
  end

  # find if player hits blackjack
  def blackjack?(hand)
    calculate_total(hand) == 21 &&
    hand.length == 2
  end

end

before do
  @show_hit_or_stay_buttons = true
  @show_play_or_quit_buttons = false
  @show_continue_button = false
end

get '/' do
  if session[:player_name]
    redirect '/game'
  else
    redirect '/new_player'
  end
end

get '/new_player' do
  erb :new_player
end

post '/new_player' do
  if params[:player_name].empty?
    @error = "Name is required"
    halt erb(:new_player)
  end

  session[:player_name] = params[:player_name]
  session[:player_money] = INITIAL_POT_AMOUNT

  redirect '/bet'
end

get '/bet' do  
  if broke?(session[:player_money])
    redirect '/game_over'
  end
  session[:player_bet] = nil
  erb :bet
end

post '/bet' do
  if incorrect_bet?(params[:player_bet])
    @error = "Bet is incorrect"
    halt erb(:bet)
  end

  session[:player_bet] = params[:player_bet].to_i
  redirect '/game'
end

get '/game' do
  session[:turn] = session[:player_name]
  session[:player_blackjack] = false

  # create a deck and put it in session
  suits = ['H', 'D', 'C', 'S']
  values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']
  session[:deck] = suits.product(values).shuffle!

  # deal cards
  session[:dealer_cards] = []
  session[:player_cards] = []
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop

  player_total = calculate_total(session[:player_cards])

  # player hits blackjack
  if blackjack?(session[:player_cards])
    @show_hit_or_stay_buttons = false
    @show_continue_button = true
    session[:player_blackjack] = true
    @winner = "#{session[:player_name]} draws a blackjack!"
  end

  erb :game
end

post '/game/player/hit' do
  session[:player_cards] << session[:deck].pop

  player_total = calculate_total(session[:player_cards])
  if player_total == BLACKJACK_AMOUNT
    @show_hit_or_stay_buttons = false
    @show_continue_button = true
    @winner = "#{session[:player_name]} stays at 21."
  elsif player_total > BLACKJACK_AMOUNT
    loser!("It looks like #{session[:player_name]} busted with #{player_total}")
  end

  erb :game, layout: false
end

post '/game/player/stay' do
  @winner = "#{session[:player_name]} has chosen to stay"
  @show_hit_or_stay_buttons = false
  redirect '/game/dealer'
end

get '/game/dealer' do
  session[:turn] = "dealer"
  @show_hit_or_stay_buttons = false

  # decision tree
  dealer_total = calculate_total(session[:dealer_cards])
  player_total = calculate_total(session[:player_cards])

  if blackjack?(session[:dealer_cards]) && session[:player_blackjack]
    # dealer and player both hit blackjack
    tie!("Both Dealer and #{session[:player_name]} hit a blackjack")

  elsif session[:player_blackjack]
    # player wins with a blackjack
    session[:player_bet] = (session[:player_bet] * 1.5).to_i
    # player is rewarded 50% more money for blackjack
    winner!("#{session[:player_name]} wins with a blackjack")

  elsif blackjack?(session[:dealer_cards]) && player_total == BLACKJACK_AMOUNT
    # dealer hits blackjack but player pushes with a score of 21
    tie!("Dealer hits blackjack, but #{session[:player_name]} is safe at 21")

  elsif blackjack?(session[:dealer_cards])
    # dealer wins with a blackjack
    loser!("Dealer hits blackjack")

  elsif dealer_total > BLACKJACK_AMOUNT
    # dealer busts
    winner!("Dealer has busted at #{dealer_total}")

  elsif dealer_total >= DEALER_MIN_HIT || dealer_total > player_total
    # dealer stays
    redirect '/game/compare'
  else
    # dealer hits
    @show_dealer_hit_button = true
  end

  erb :game, layout: false
end

post '/game/dealer/hit' do
  session[:dealer_cards] << session[:deck].pop
  redirect '/game/dealer'
end

get '/game/compare' do
  player_total = calculate_total(session[:player_cards])
  dealer_total = calculate_total(session[:dealer_cards])

  if player_total < dealer_total
    loser!("#{session[:player_name]} stayed at #{player_total}, and the dealer stayed at #{dealer_total}")
  elsif player_total > dealer_total
    winner!("#{session[:player_name]} stayed at #{player_total}, and the dealer stayed at #{dealer_total}")
  elsif
    tie!("Both #{session[:player_name]} and the dealer stayed at #{player_total}")
  end

  erb :game, layout: false
end

get '/game_over' do
  erb :game_over
end