require 'rails_helper'

describe MoviesController, type: :controller do
  describe 'searching TMDb' do
    let(:search) do
      { title: 'hardware', release_year: '', language: 'en' }
    end

    before(:each) do
      @fake_results = [double('movie1'), double('movie2')]
    end

    it 'calls the model method with the search fields' do
      expect(Movie).to receive(:find_in_tmdb)
        .with(search)
        .and_return(@fake_results)

      get :search_tmdb, params: search
    end

    describe 'after valid search' do
      before(:each) do
        allow(Movie).to receive(:find_in_tmdb)
          .and_return(@fake_results)

        get :search_tmdb, params: search
      end

      it 'selects the Search Results template for rendering' do
        expect(response).to render_template('search_tmdb')
      end

      it 'makes the TMDb search results available to that template' do
        expect(assigns(:movies)).to eq(@fake_results)
      end
    end

    it 'opens the search page without performing a search' do
      expect(Movie).not_to receive(:find_in_tmdb)

      get :search_tmdb

      expect(response).to render_template('search_tmdb')
      expect(flash).to be_empty
    end

    it 'rejects a missing title on a submitted search' do
      expect(Movie).not_to receive(:find_in_tmdb)

      get :search_tmdb, params: { language: 'en' }

      expect(flash[:danger])
        .to eq('Please fill in all required fields!')
    end

    it 'rejects a whitespace-only title' do
      expect(Movie).not_to receive(:find_in_tmdb)

      get :search_tmdb, params: search.merge(title: '   ')

      expect(flash[:danger])
        .to eq('Please fill in all required fields!')
    end

    it 'reports that no movies matched' do
      allow(Movie).to receive(:find_in_tmdb).and_return([])

      get :search_tmdb, params: search

      expect(flash[:warning])
        .to eq('No movies found with given parameters!')
      expect(assigns(:movies)).to eq([])
    end

    it 'displays a model error without crashing' do
      allow(Movie).to receive(:find_in_tmdb)
        .and_raise(Movie::TmdbError, 'Invalid TMDb API key.')

      get :search_tmdb, params: search

      expect(flash[:danger]).to eq('Invalid TMDb API key.')
      expect(assigns(:movies)).to eq([])
    end
  end

  describe 'adding a movie' do
    it 'saves the submitted movie and redirects with confirmation' do
      attributes = {
        title: 'Manhunter',
        rating: 'R',
        release_date: '1986-08-15',
        description: 'A crime thriller.'
      }

      expect {
        post :add_movie, params: { movie: attributes }
      }.to change(Movie, :count).by(1)

      movie = Movie.order(:id).last
      expect(movie.title).to eq('Manhunter')
      expect(movie.rating).to eq('R')
      expect(movie.release_date).to eq(Date.new(1986, 8, 15))
      expect(movie.description).to eq('A crime thriller.')

      expect(response).to redirect_to(search_tmdb_path)
      expect(flash[:success])
        .to eq('Manhunter was successfully added to RottenPotatoes.')
    end
  end
end