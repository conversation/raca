require 'spec_helper'

describe Raca::WindowedIO do
  let(:source_io) { StringIO.new("0123456789") }

  describe '#pos' do
    let(:windowed_io) { Raca::WindowedIO.new(source_io, 2, 3)}

    context 'after initialization' do
      it 'returns 0' do
        expect(windowed_io.pos).to eq 0
      end
    end
  end

  describe '#size' do
    let(:windowed_io) { Raca::WindowedIO.new(source_io, 2, 3)}

    context 'with a 3-byte window' do
      it 'returns 3' do
        expect(windowed_io.size).to eq 3
      end
    end
  end

  describe 'behaviours' do
    let(:windowed_io) { Raca::WindowedIO.new(source_io, 2, 3)}

    context 'with a 3-byte window' do
      it 'behaves as expected while reading single bytes' do
        expect(windowed_io.pos).to eq 0
        expect(windowed_io.size).to eq 3
        expect(windowed_io.read(1)).to eq "2"
        expect(windowed_io.pos).to eq 1
        expect(windowed_io.read(1)).to eq "3"
        expect(windowed_io.pos).to eq 2
        expect(windowed_io.read(1)).to eq "4"
        expect(windowed_io.eof?).to be true
      end

      it 'behaves as expected while reading past the window' do
        expect(windowed_io.pos).to eq 0
        expect(windowed_io.size).to eq 3
        expect(windowed_io.read(4)).to eq "234"
        expect(windowed_io.pos).to eq 3
        expect(windowed_io.eof?).to be true
      end

      it 'behaves as expected while seeking' do
        expect(windowed_io.pos).to eq 0
        expect(windowed_io.seek(1))
        expect(windowed_io.pos).to eq 1
        expect(windowed_io.read(1)).to eq '3'
      end

      it 'behaves as expected while seeking to a negative pos' do
        expect(windowed_io.pos).to eq 0
        expect(windowed_io.seek(1))
        expect(windowed_io.pos).to eq 1
        expect(windowed_io.seek(-1))
        expect(windowed_io.pos).to eq 0
      end

      it 'behaves as expected while seeking past the end of the window' do
        expect(windowed_io.pos).to eq 0
        expect(windowed_io.seek(5))
        expect(windowed_io.pos).to eq 3
        expect(windowed_io.eof?).to be true
      end
    end

    context 'with a 3-byte window that passes the end of the source IO' do
      let(:window_passes_source) { Raca::WindowedIO.new(source_io, 7, 4)}

      it 'behaves as expected while reading past the window' do
        expect(window_passes_source.pos).to eq 0
        expect(window_passes_source.size).to eq 3
        expect(window_passes_source.readpartial(4)).to eq "789"
        expect(window_passes_source.pos).to eq 3
        expect(window_passes_source.eof?).to be true
      end
    end
  end
end
