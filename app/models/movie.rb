class Movie < ActiveRecord::Base
class TmdbError < StandardError; end

def self.find_in_tmdb(search_params, api_key = ENV['TMDB_API_KEY'])
  if api_key.blank?
    raise TmdbError, 'TMDb API key is not configured.'
  end

  search_params = search_params.to_h.symbolize_keys

  query = {
    api_key: api_key,
    query: search_params[:title].to_s.strip
  }

  year = search_params[:release_year].to_s.strip
  query[:year] = year unless year.empty?

  english_only = search_params[:language] == 'en'
  query[:language] = 'en-US' if english_only

  response = Faraday.get(
    'https://api.themoviedb.org/3/search/movie',
    query
  )

  if response.status == 401
    raise TmdbError, 'Invalid TMDb API key.'
  end

  unless response.status == 200
    raise TmdbError, 'TMDb search is temporarily unavailable. Please try again.'
  end

  results = JSON.parse(response.body).fetch('results')

  if english_only
    results = results.select do |result|
      result['original_language'] == 'en'
    end
  end

  results.map do |result|
    new(
      title: result.fetch('title'),
      rating: 'R',
      release_date: result['release_date'].presence,
      description: result['overview']
    )
  end
  rescue Faraday::Error, JSON::ParserError, KeyError
    raise TmdbError, 'TMDb search is temporarily unavailable. Please try again.'
  end

  def self.all_ratings
    %w[G PG PG-13 R]
  end

  def self.with_ratings(ratings, sort_by)
    if ratings.nil?
      all.order sort_by
    else
      where(rating: ratings.map(&:upcase)).order sort_by
    end
  end
end