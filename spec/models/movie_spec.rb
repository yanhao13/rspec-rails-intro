require 'spec_helper'
require 'rails_helper'

describe Movie, type: :model do
  let(:endpoint) { 'https://api.themoviedb.org/3/search/movie' }
  let(:search) do
    { title: 'Olympics', release_year: '2000', language: 'en' }
  end

  describe '.find_in_tmdb' do
    it 'calls Faraday to perform the search' do
      expect(Faraday).to receive(:get).and_call_original

      Movie.find_in_tmdb(search, 'test-key')
    end

    it 'sends the API key, title, year, and language' do
      Movie.find_in_tmdb(search, 'test-key')

      expect(WebMock).to have_requested(:get, endpoint).with(
        query: {
          'api_key' => 'test-key',
          'query' => 'Olympics',
          'year' => '2000',
          'language' => 'en-US'
        }
      )
    end

    it 'returns correctly populated movies without saving them' do
      movies = nil

      expect {
        movies = Movie.find_in_tmdb(search, 'test-key')
      }.not_to change(Movie, :count)

      expect(movies.length).to eq(2)
      expect(movies).to all(be_a(Movie))
      expect(movies).to all(be_new_record)
      expect(movies.map(&:rating)).to eq(['R', 'R'])

      expect(movies.first.title)
        .to eq('Sydney 2000 Olympics Opening Ceremony')
      expect(movies.first.release_date).to eq(Date.new(2000, 9, 15))
      expect(movies.first.description)
        .to eq('Coverage of the opening ceremony.')
    end

    it 'supports special characters and an omitted release year' do
      Movie.find_in_tmdb(
        { title: 'This Life + 10', release_year: '', language: 'all' },
        'test-key'
      )

      expect(WebMock).to have_requested(:get, endpoint).with(
        query: {
          'api_key' => 'test-key',
          'query' => 'This Life + 10'
        }
      )
    end

    context 'when results contain multiple original languages' do
      before do
        body = {
          results: [
            { title: 'English Movie', original_language: 'en' },
            { title: 'French Movie', original_language: 'fr' }
          ]
        }

        stub_request(:get, endpoint)
          .with(query: hash_including('api_key' => 'test-key'))
          .to_return(status: 200, body: JSON.generate(body))
      end

      it 'keeps only English movies when English Only is selected' do
        movies = Movie.find_in_tmdb(search, 'test-key')

        expect(movies.map(&:title)).to eq(['English Movie'])
      end

      it 'keeps all languages when All Languages is selected' do
        movies = Movie.find_in_tmdb(
          search.merge(language: 'all'), 'test-key'
        )

        expect(movies.map(&:title))
          .to eq(['English Movie', 'French Movie'])
      end
    end

    it 'returns an empty array when no movies match' do
      stub_request(:get, endpoint)
        .with(query: hash_including('api_key' => 'test-key'))
        .to_return(status: 200, body: '{"results":[]}')

      expect(Movie.find_in_tmdb(search, 'test-key')).to eq([])
    end

    it 'reports an invalid API key' do
      stub_request(:get, endpoint)
        .with(query: hash_including('api_key' => 'bad-key'))
        .to_return(status: 401, body: '{"status_message":"Invalid key"}')

      expect {
        Movie.find_in_tmdb(search, 'bad-key')
      }.to raise_error(Movie::TmdbError, 'Invalid TMDb API key.')
    end

    it 'reports a network timeout' do
      stub_request(:get, endpoint)
        .with(query: hash_including('api_key' => 'test-key'))
        .to_timeout

      expect {
        Movie.find_in_tmdb(search, 'test-key')
      }.to raise_error(Movie::TmdbError, /temporarily unavailable/)
    end
  end
end